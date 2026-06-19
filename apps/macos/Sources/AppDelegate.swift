import AppKit
import SwiftUI

/// 应用委托：菜单栏状态项 + 主窗口 + 生命周期。
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private let annotation = AnnotationController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // mM0：先用 .regular（带 Dock 图标 + 启动即显窗口），便于验收；mM11 改 .accessory 常驻菜单栏。
        NSApp.setActivationPolicy(.regular)
        setupStatusItem()
        showMainWindow()

        // mM3：注册全局快捷键 ⌃⇧1。
        HotkeyManager.shared.register { [weak self] in
            self?.onHotkey()
        }

        // mM4：启动时按保留策略清理过期备份（后台，不阻塞）。
        let backupDir = model.settings.screenshotBackupDir
        let retention = model.settings.screenshotRetentionDays
        DispatchQueue.global().async {
            CaptureService().cleanupBackups(backupDirConfigured: backupDir,
                                            retentionDays: retention)
        }
    }

    /// 快捷键触发 → 抓前台来源 → 启动区域截图。
    private func onHotkey() {
        model.hotkeyCount += 1
        // mM8：在弹任何自己的 UI 前抓前台应用/窗口。
        var fg = ForegroundApp.capture()
        // mM9：前台是浏览器则取当前页 URL（Apple Events）。
        if BrowserURL.isBrowser(bundleId: fg.bundleId) {
            fg.url = BrowserURL.currentURL(bundleId: fg.bundleId)
        }
        Log.write("hotkey: count=\(model.hotkeyCount) fg=\(fg.appName)|\(fg.bundleId)|\(fg.windowTitle) url=\(fg.url)")
        Task { @MainActor in await self.startCapture(foreground: fg) }
    }

    /// mM4：系统原生框选 → 存备份目录 → 弹批注。
    @MainActor
    private func startCapture(foreground fg: ForegroundInfo) async {
        let svc = CaptureService()
        guard let temp = await svc.captureInteractive() else {
            Log.write("capture: 取消或失败")
            return   // 用户取消，静默
        }
        guard let shot = svc.saveToBackup(
            tempPath: temp,
            backupDirConfigured: model.settings.screenshotBackupDir) else { return }
        try? FileManager.default.removeItem(atPath: temp)
        Log.write("capture: saved \(shot.path) \(shot.pixelWidth)x\(shot.pixelHeight)")
        model.lastShotPath = shot.path

        // mM6：弹批注窗 → 保存时走 Markdown 生成 + Obsidian 写入。
        let img = NSImage(contentsOfFile: shot.path) ?? NSImage()
        annotation.present(
            image: img,
            sourceApp: fg.appName,
            onSave: { note in
                Task { @MainActor in await self.saveCapture(note: note, shot: shot, foreground: fg) }
            },
            onCancel: {
                Log.write("annotation: 取消")
            })
    }

    /// mM6+mM7：批注 → AI 识别(失败降级) → Markdown → 写入 Obsidian 库。后台进行，不阻塞。
    @MainActor
    private func saveCapture(note: String, shot: CaptureShot, foreground fg: ForegroundInfo) async {
        let s = model.settings
        guard s.isConfigured else {
            Log.write("save: 未配置 Vault，跳过")
            model.milestone = "未设置 Obsidian 库，无法保存"
            showMainWindow()
            return
        }

        var record = CaptureRecord()
        record.userNote = note
        record.screenshotPath = shot.path
        record.vaultPath = s.vaultPath
        record.sourceApp = fg.appName
        record.sourceWindowTitle = fg.windowTitle
        record.sourceUrl = fg.url.isEmpty ? nil : fg.url
        record.status = .saved

        // mM7：AI 识别填充 标题/摘要/OCR/标签。任何失败都降级（留空字段）继续保存。
        model.milestone = "AI 整理中…"
        let apiKey = Credentials.aiApiKey
        if !apiKey.isEmpty,
           let png = try? Data(contentsOf: URL(fileURLWithPath: shot.path)) {
            do {
                let ai = AIService(baseURL: s.aiBaseUrl, apiKey: apiKey, model: s.aiModel)
                let r = try await ai.analyzeCapture(pngData: png, userNote: note)
                record.aiTitle = r.title
                record.aiSummary = r.summary
                record.ocrText = r.ocrText
                record.tags = r.tags
                Log.write("ai: ok title=\(r.title) tags=\(r.tags) ocr=\(r.ocrText.count)字")
            } catch {
                record.status = .aiFailed
                Log.write("ai: 失败降级 \(error.localizedDescription)")
            }
        } else {
            Log.write("ai: 跳过（无 API Key 或读图失败）")
        }

        // 写入 Obsidian
        let markdown = MarkdownBuilder().generate(record)
        do {
            let res = try ObsidianWriter().writeNote(
                vaultPath: s.vaultPath,
                capturesDir: s.capturesDir,
                baseName: record.displayTitle,
                markdown: markdown)
            Log.write("save: 写入 \(res.markdownPath)")
            record.markdownPath = res.markdownPath
            model.lastSavedPath = res.markdownPath
            model.lastSavedName = res.fileName
            model.milestone = record.status == .aiFailed
                ? "AI 失败，已降级保存：\(res.fileName)"
                : "已保存：\(res.fileName)"

            // 留存策略 0=用完即删：写完笔记后删掉截图备份。
            if s.screenshotRetentionDays == 0 {
                try? FileManager.default.removeItem(atPath: shot.path)
                record.screenshotPath = nil
            }

            // mM10：入历史。
            model.addHistory(record)
        } catch {
            Log.write("save: 失败 \(error)")
            model.milestone = "保存失败：\(error.localizedDescription)"
        }
        showMainWindow()
    }

    // 关掉窗口不退出进程（菜单栏常驻）。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "viewfinder",
                              accessibilityDescription: "SnapMind")
            img?.isTemplate = true
            button.image = img
        }
        let menu = NSMenu()
        addItem(to: menu, title: "显示 SnapMind", action: #selector(showMainWindow))
        addItem(to: menu, title: "设置…", action: #selector(openSettings), key: ",")
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 SnapMind",
                              action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        statusItem.menu = menu
    }

    private func addItem(to menu: NSMenu, title: String, action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    @objc func showMainWindow() {
        if window == nil {
            let hosting = NSHostingController(rootView: RootView().environment(model))
            let win = NSWindow(contentViewController: hosting)
            win.title = "SnapMind · 瞬念"
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.setContentSize(NSSize(width: 860, height: 560))
            win.center()
            win.isReleasedWhenClosed = false
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc func openSettings() {
        // mM1 实现独立设置窗；当前先复用主窗。
        showMainWindow()
    }
}

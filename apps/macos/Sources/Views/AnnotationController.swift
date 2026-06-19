import AppKit
import SwiftUI

/// 批注浮动窗（NSPanel）控制器：截图后弹出，收集想法后回调。
final class AnnotationController {
    private var panel: NSPanel?

    /// 展示批注窗。onSave 带用户想法；onCancel 表示放弃本次。
    func present(image: NSImage,
                 sourceApp: String,
                 onSave: @escaping (String) -> Void,
                 onCancel: @escaping () -> Void) {
        close()

        let view = AnnotationView(
            image: image,
            sourceApp: sourceApp,
            onSave: { [weak self] note in self?.close(); onSave(note) },
            onCancel: { [weak self] in self?.close(); onCancel() })

        let hosting = NSHostingController(rootView: view)
        let panel = NSPanel(contentViewController: hosting)
        // 显式固定尺寸：避免让窗口去查询 SwiftUI 理想尺寸（含 maxWidth:.infinity 会算出无限宽 → 布局崩溃）。
        panel.setContentSize(NSSize(width: 420, height: 480))
        panel.styleMask = [.titled, .closable, .fullSizeContentView, .nonactivatingPanel]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.center()
        self.panel = panel

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.close()
        panel = nil
    }
}

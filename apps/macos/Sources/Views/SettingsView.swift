import AppKit
import SwiftUI

/// 设置页：知识库 / 截图备份 / 快捷键 / AI 服务。改动即时持久化（非密→UserDefaults，Key→Keychain）。
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var apiKey = ""
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        @Bindable var model = model

        Form {
            Section("知识库") {
                folderRow(title: "Obsidian 库", path: $model.settings.vaultPath,
                          placeholder: "选择 Vault 根目录")
                TextField("笔记目录（相对库）", text: $model.settings.capturesDir,
                          prompt: Text("Inbox/Captures"))
            }

            Section("截图备份") {
                folderRow(title: "备份文件夹", path: $model.settings.screenshotBackupDir,
                          placeholder: "留空＝默认（应用支持目录）")
                Picker("保留时长", selection: $model.settings.screenshotRetentionDays) {
                    ForEach(RetentionOption.options) { opt in
                        Text(opt.label).tag(opt.days)
                    }
                }
                Text("截图不嵌入笔记，仅作可回看的临时备份，到期自动清理。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("快捷键") {
                LabeledContent("截图快捷键") {
                    Text(model.settings.hotkey)
                        .font(.body.monospaced().weight(.semibold))
                        .foregroundStyle(Theme.brand)
                }
                Text("mM3 支持自定义录制，当前固定为 ⌃⇧1。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("AI 服务（OpenAI 兼容多模态）") {
                Picker("服务商预设", selection: providerSelection) {
                    ForEach(AiProviderPreset.presets) { p in
                        Text(p.label).tag(p.baseUrl)
                    }
                }
                TextField("Base URL", text: $model.settings.aiBaseUrl,
                          prompt: Text("https://api.minimax.io/v1"))
                SecureField("API Key", text: $apiKey, prompt: Text("存入系统钥匙串"))
                    .onChange(of: apiKey) { _, v in Credentials.aiApiKey = v }
                TextField("模型 id", text: $model.settings.aiModel,
                          prompt: Text("MiniMax-M3"))
                Text("模型必须支持读图（多模态）。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("启动") {
                Toggle("开机自启", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        LoginItem.setEnabled(on)
                        launchAtLogin = LoginItem.isEnabled
                    }
                Text("登录后在后台常驻菜单栏，随时 ⌃⇧1 截图。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            apiKey = Credentials.aiApiKey
            launchAtLogin = LoginItem.isEnabled
        }
        .onChange(of: model.settings) { _, new in SettingsStore.save(new) }
    }

    // 选中预设时把 baseUrl 写进设置；"自定义" 不改动现有值。
    private var providerSelection: Binding<String> {
        Binding(
            get: {
                let url = model.settings.aiBaseUrl
                return AiProviderPreset.presets.contains { $0.baseUrl == url } ? url : ""
            },
            set: { newUrl in
                if !newUrl.isEmpty { model.settings.aiBaseUrl = newUrl }
            }
        )
    }

    @ViewBuilder
    private func folderRow(title: String, path: Binding<String>, placeholder: String) -> some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                TextField("", text: path, prompt: Text(placeholder))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                Button("选择…") {
                    if let p = Self.pickFolder() { path.wrappedValue = p }
                }
            }
        }
    }

    static func pickFolder() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}

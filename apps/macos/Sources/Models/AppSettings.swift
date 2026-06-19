import Foundation

/// 应用设置（不含 API Key —— Key 单独走 Keychain）。对齐 Windows 版 app_settings.dart。
struct AppSettings: Codable, Equatable {
    /// Obsidian Vault 根目录（绝对路径）。
    var vaultPath: String
    /// 笔记保存目录（相对 Vault），如 Inbox/Captures。
    var capturesDir: String
    /// 截图备份文件夹（绝对路径，可在 Vault 之外）。留空用默认 ~/Library/Application Support/SnapMind/Screenshots。
    var screenshotBackupDir: String
    /// 截图备份保留天数。0=用完即删，-1=永久，N=保留 N 天。
    var screenshotRetentionDays: Int
    /// 全局快捷键展示串（mM3 用结构化配置替换解析）。
    var hotkey: String
    /// AI 服务 baseURL（OpenAI 兼容）。
    var aiBaseUrl: String
    /// AI 模型 id（必须多模态）。
    var aiModel: String

    static let defaults = AppSettings(
        vaultPath: "",
        capturesDir: "Inbox/Captures",
        screenshotBackupDir: "",
        screenshotRetentionDays: 7,
        hotkey: "⌃⇧1",
        aiBaseUrl: "https://api.minimax.io/v1",
        aiModel: "MiniMax-M3"
    )

    /// 至少设置了 Vault 路径才算最小可用。
    var isConfigured: Bool {
        !vaultPath.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// AI 服务商预设：一键填入对应 OpenAI 兼容 baseURL。
struct AiProviderPreset: Identifiable, Hashable {
    let label: String
    let baseUrl: String
    var id: String { label }

    static let presets: [AiProviderPreset] = [
        .init(label: "MiniMax（国际）", baseUrl: "https://api.minimax.io/v1"),
        .init(label: "MiniMax（国内）", baseUrl: "https://api.minimaxi.com/v1"),
        .init(label: "OpenAI", baseUrl: "https://api.openai.com/v1"),
        .init(label: "DeepSeek", baseUrl: "https://api.deepseek.com/v1"),
        .init(label: "通义 DashScope", baseUrl: "https://dashscope.aliyuncs.com/compatible-mode/v1"),
        .init(label: "智谱 GLM", baseUrl: "https://open.bigmodel.cn/api/paas/v4"),
        .init(label: "本地 Ollama", baseUrl: "http://localhost:11434/v1"),
        .init(label: "自定义", baseUrl: ""),
    ]
}

/// 截图备份保留时长选项。
struct RetentionOption: Identifiable, Hashable {
    let label: String
    let days: Int
    var id: Int { days }

    static let options: [RetentionOption] = [
        .init(label: "不保留（用完即删）", days: 0),
        .init(label: "保留 1 天", days: 1),
        .init(label: "保留 7 天", days: 7),
        .init(label: "保留 30 天", days: 30),
        .init(label: "永久保留", days: -1),
    ]
}

import Foundation
import Observation

/// 全局状态（@Observable，沿用 DriftMac 约定）。
@Observable
final class AppModel {
    /// 当前里程碑标记（脚手架占位）。
    var milestone: String = "mM3 全局快捷键就绪"

    /// 快捷键触发次数。
    var hotkeyCount: Int = 0

    /// 最近一次截图的备份路径（mM4 验证用）。
    var lastShotPath: String?

    /// 最近一次保存的笔记路径 + 文件名（mM6 反馈）。
    var lastSavedPath: String?
    var lastSavedName: String?

    /// 应用设置（启动时从 UserDefaults 载入）。
    var settings: AppSettings

    /// 历史记录（最新在前）。
    var history: [CaptureRecord]

    init() {
        settings = SettingsStore.load()
        history = HistoryStore.load()
    }

    /// 持久化当前设置（非密部分）。
    func persistSettings() {
        SettingsStore.save(settings)
    }

    /// 新增一条历史（插到最前）并持久化。
    func addHistory(_ record: CaptureRecord) {
        history.insert(record, at: 0)
        HistoryStore.save(history)
    }

    /// 删除一条历史（连带 .md 文件）并持久化。
    func deleteHistory(_ record: CaptureRecord) {
        if !record.markdownPath.isEmpty {
            try? FileManager.default.removeItem(atPath: record.markdownPath)
        }
        history.removeAll { $0.id == record.id }
        HistoryStore.save(history)
    }
}

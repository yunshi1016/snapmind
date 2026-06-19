import Foundation

/// 记录状态。
enum CaptureStatus: String, Codable {
    case draft      // 草稿（批注中）
    case saving     // 写入中
    case saved      // 已写入
    case aiFailed   // AI 失败但已降级保存
}

/// 一次捕获的领域模型（Codable，供历史持久化）。对齐 Windows capture_record.dart。
struct CaptureRecord: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var createdAt: Date = Date()

    /// 用户写下的「我的想法」。
    var userNote: String = ""

    /// 截图备份路径（不嵌入笔记；到期清理后可能失效）。
    var screenshotPath: String? = nil

    var vaultPath: String = ""
    var markdownPath: String = ""

    var ocrText: String = ""
    var aiTitle: String = ""
    var aiSummary: String = ""
    var tags: [String] = []

    var sourceApp: String = ""
    var sourceWindowTitle: String = ""
    var sourceUrl: String? = nil

    var status: CaptureStatus = .draft

    /// 展示/文件名用标题：优先 AI 标题，退化到批注首行，再退化到默认。
    var displayTitle: String {
        let t = aiTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let firstLine = userNote
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        if !firstLine.isEmpty { return firstLine }
        return "未命名捕获"
    }
}

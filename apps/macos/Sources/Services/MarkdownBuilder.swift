import Foundation

/// 把 CaptureRecord 渲染成 Obsidian Markdown（YAML frontmatter + 纯内容正文）。
/// 对齐 Windows markdown_generator.dart。决策：笔记不嵌入截图。
struct MarkdownBuilder {

    func generate(_ r: CaptureRecord) -> String {
        let title = r.displayTitle
        let tags = r.tags.map(Self.sanitizeTag).filter { !$0.isEmpty }

        var fm = "---\n"
        fm += "title: \(Self.yaml(title))\n"
        fm += "created: \(Self.iso(r.createdAt))\n"
        if !tags.isEmpty {
            fm += "tags:\n"
            for t in tags { fm += "  - \(t)\n" }
        }
        if !trim(r.sourceApp).isEmpty {
            fm += "source_app: \(Self.yaml(trim(r.sourceApp)))\n"
        }
        if !trim(r.sourceWindowTitle).isEmpty {
            fm += "source_window: \(Self.yaml(trim(r.sourceWindowTitle)))\n"
        }
        if let u = r.sourceUrl, !trim(u).isEmpty {
            fm += "source_url: \(Self.yaml(trim(u)))\n"
        }
        fm += "---\n"

        var body = ""
        body += "# \(title)\n\n"
        body += "## 我的想法\n\n\(orDash(r.userNote))\n\n"
        body += "## AI 摘要\n\n\(orPlaceholder(r.aiSummary, "_（暂无 AI 摘要）_"))\n\n"
        let ocr = trim(r.ocrText)
        let ocrBody = ocr.isEmpty ? "_（暂无 OCR 文本）_" : OcrMarkdown.normalize(ocr)
        body += "## OCR 识别\n\n\(ocrBody)\n\n"
        body += "## 来源信息\n\n"
        body += "- 应用：\(orDash(r.sourceApp))\n"
        body += "- 窗口标题：\(orDash(r.sourceWindowTitle))\n"
        body += "- 来源链接：\(orDash(r.sourceUrl ?? ""))\n"
        body += "- 时间：\(Self.humanTime(r.createdAt))\n\n"
        body += "## 标签\n\n"
        body += tags.isEmpty ? "—" : tags.map { "#\($0)" }.joined(separator: " ")
        body += "\n"

        return fm + "\n" + body
    }

    // MARK: - helpers

    private func trim(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func orDash(_ s: String) -> String {
        trim(s).isEmpty ? "—" : trim(s)
    }

    private func orPlaceholder(_ s: String, _ placeholder: String) -> String {
        trim(s).isEmpty ? placeholder : trim(s)
    }

    static func sanitizeTag(_ t: String) -> String {
        t.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
    }

    static func yaml(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    static func iso(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: d)
    }

    static func humanTime(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: d)
    }
}

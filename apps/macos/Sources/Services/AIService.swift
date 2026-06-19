import Foundation

/// AI 识别结果（任一字段都可能为空，调用方自行降级）。
struct AICaptureResult {
    let ocrText: String
    let title: String
    let summary: String
    let tags: [String]
}

/// 带 stage 的 AI 错误（错误自诊断，沿用 DriftAPI 思路）。
struct AIServiceError: LocalizedError {
    let message: String
    let stage: String?
    var errorDescription: String? {
        if let stage { return "[\(stage)] \(message)" }
        return message
    }
}

/// OpenAI 兼容多模态客户端：截图 + 用户批注 → OCR / 标题 / 摘要 / 标签。
/// 默认 MiniMax，可指向任意 OpenAI 兼容端点。失败抛异常，由调用方降级。
/// 移植自 Windows ai_service.dart（含 ###...### 分隔解析 —— 弃用 JSON 的原因是 OCR 含引号撑爆解析）。
struct AIService {
    let baseURL: String
    let apiKey: String
    let model: String

    private static let systemPrompt = """
    你是 SnapMind 截图知识助手。用户截取了一块屏幕区域并写下了自己的想法。
    TITLE / SUMMARY / TAGS 一律用简体中文输出（即使截图内容是英文，也要用中文转述）；
    OCR 项保留截图里文字的原始语言。
    严格按下面的模板输出：每个标记 ###XXX### 单独占一行，下面紧跟该项内容。
    不要输出 JSON、不要代码块、不要任何额外说明。各项内容里可以自由使用任何标点（包括引号、换行）。

    ###TITLE###
    （简洁中文标题，不超过 20 字，不带书名号/引号）
    ###SUMMARY###
    （2~4 句中文摘要：以知识总结的视角，直接提炼内容本身的核心信息、观点或结论，像读书笔记的要点，方便日后回顾。禁止描述画面或行为，禁止出现「截图」「图片」「用户」「界面」等字眼）
    ###OCR###
    （截图中的全部可读文字，保留合理换行；没有文字则此项留空）
    ###TAGS###
    （2~5 个中文标签，用中文顿号、或英文逗号分隔，不带 # 号）
    """

    func analyzeCapture(pngData: Data, userNote: String) async throws -> AICaptureResult {
        let trimmed = baseURL.trimmingCharacters(in: .whitespaces)
        let base = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        guard let url = URL(string: base + "/chat/completions") else {
            throw AIServiceError(message: "AI baseURL 无效：\(baseURL)", stage: "config")
        }

        let dataUri = "data:image/png;base64,\(pngData.base64EncodedString())"
        let note = userNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let textContent = note.isEmpty
            ? "（用户没有写想法，请只根据截图内容生成。）"
            : "我的想法：\(note)"

        let body: [String: Any] = [
            "model": model,
            "temperature": 0.3,
            "messages": [
                ["role": "system", "content": Self.systemPrompt],
                ["role": "user", "content": [
                    ["type": "text", "text": textContent],
                    ["type": "image_url", "image_url": ["url": dataUri]],
                ] as [[String: Any]]],
            ],
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw AIServiceError(message: error.localizedDescription, stage: "network")
        }

        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let snippet = String(data: data, encoding: .utf8)?.prefix(300) ?? ""
            throw AIServiceError(message: "HTTP \(http.statusCode) \(snippet)", stage: "http")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AIServiceError(message: "AI 返回内容为空或格式异常", stage: "parse")
        }

        let result = Self.parse(content)
        // 一个标记都没命中 → 视为失败，触发降级。
        if result.title.isEmpty && result.summary.isEmpty
            && result.ocrText.isEmpty && result.tags.isEmpty {
            throw AIServiceError(message: "AI 输出未含任何标记", stage: "parse")
        }
        return result
    }

    /// 按 ###TITLE### / ###SUMMARY### / ###OCR### / ###TAGS### 切分。字段内含引号/换行不影响。
    static func parse(_ raw: String) -> AICaptureResult {
        let keys = ["TITLE", "SUMMARY", "OCR", "TAGS"]
        var map: [String: String] = [:]
        let ns = raw as NSString
        for key in keys {
            let start = ns.range(of: "###\(key)###")
            if start.location == NSNotFound { continue }
            let contentStart = start.location + start.length
            var end = ns.length
            for other in keys where other != key {
                let r = ns.range(of: "###\(other)###",
                                 range: NSRange(location: contentStart, length: ns.length - contentStart))
                if r.location != NSNotFound && r.location < end { end = r.location }
            }
            map[key] = ns.substring(with: NSRange(location: contentStart, length: end - contentStart))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let tags = (map["TAGS"] ?? "")
            .components(separatedBy: CharacterSet(charactersIn: ",，、\n"))
            .map { $0.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return AICaptureResult(
            ocrText: map["OCR"] ?? "",
            title: map["TITLE"] ?? "",
            summary: map["SUMMARY"] ?? "",
            tags: tags)
    }
}

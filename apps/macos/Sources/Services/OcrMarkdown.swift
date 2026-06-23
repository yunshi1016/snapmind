import Foundation

/// 把 AI 给的 OCR Markdown 调整成可安全嵌入笔记的 Obsidian Markdown。
/// 笔记自身用 # 作标题、## 作段落（我的想法/AI 摘要/OCR…），所以 OCR 内的标题
/// 必须 ≥ ###，否则会破坏整篇大纲。这里把任何 # / ## 标题降级到 ###，
/// 并**跳过代码围栏内的行**（避免把代码里的 # 注释误当标题）。
enum OcrMarkdown {
    static func normalize(_ raw: String) -> String {
        let text = raw.replacingOccurrences(of: "\r\n", with: "\n")
        var inFence = false
        var out: [String] = []

        for line in text.components(separatedBy: "\n") {
            let stripped = line.drop(while: { $0 == " " })

            // 代码围栏开关（``` 或 ~~~）
            if stripped.hasPrefix("```") || stripped.hasPrefix("~~~") {
                inFence.toggle()
                out.append(line)
                continue
            }

            if !inFence, let level = atxLevel(stripped), level < 3 {
                // 在第一个 # 前补足 # 让它至少为 ###
                out.append(String(repeating: "#", count: 3 - level) + stripped)
                continue
            }

            out.append(line)
        }

        return out.joined(separator: "\n")
    }

    /// 返回 ATX 标题级别（1–6）；非标题返回 nil。要求 # 后紧跟空格。
    private static func atxLevel(_ s: Substring) -> Int? {
        var n = 0
        var i = s.startIndex
        while i < s.endIndex, s[i] == "#" { n += 1; i = s.index(after: i) }
        guard n >= 1, n <= 6, i < s.endIndex, s[i] == " " else { return nil }
        return n
    }
}

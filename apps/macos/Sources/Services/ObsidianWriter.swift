import Foundation

struct ObsidianWriteResult {
    let markdownPath: String
    let fileName: String
}

/// 把 Markdown 写入 Obsidian Vault 的笔记目录。对齐 Windows obsidian_writer.dart。
/// 自动建目录、清洗非法文件名、重名追加 (1)/(2)…
struct ObsidianWriter {

    func writeNote(vaultPath: String, capturesDir: String, baseName: String,
                   markdown: String) throws -> ObsidianWriteResult {
        let dir = URL(fileURLWithPath: vaultPath, isDirectory: true)
            .appendingPathComponent(capturesDir, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let safe = Self.sanitizeFileName(baseName)
        var fileName = "\(safe).md"
        var fileURL = dir.appendingPathComponent(fileName)
        var i = 1
        while FileManager.default.fileExists(atPath: fileURL.path) {
            fileName = "\(safe) (\(i)).md"
            fileURL = dir.appendingPathComponent(fileName)
            i += 1
        }
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        return ObsidianWriteResult(markdownPath: fileURL.path, fileName: fileName)
    }

    /// 清洗非法文件名字符（\ / : * ? " < > | 与控制字符），跨平台保守处理。
    static func sanitizeFileName(_ name: String) -> String {
        var s = name.replacingOccurrences(
            of: "[\\\\/:*?\"<>|\\x00-\\x1f]", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        s = s.replacingOccurrences(of: "[ .]+$", with: "", options: .regularExpression)
        if s.isEmpty { s = "capture" }
        if s.count > 80 {
            s = String(s.prefix(80)).trimmingCharacters(in: .whitespaces)
        }
        return s
    }
}

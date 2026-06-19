import Foundation

/// 极简诊断日志，追加写到 /tmp/snapmind_diag.log（排障用，对齐 Windows 的 diag 日志思路）。
enum Log {
    private static let url = URL(fileURLWithPath: "/tmp/snapmind_diag.log")

    static func write(_ message: String) {
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let fh = try? FileHandle(forWritingTo: url) {
            defer { try? fh.close() }
            fh.seekToEndOfFile()
            fh.write(data)
        } else {
            try? data.write(to: url)
        }
    }
}

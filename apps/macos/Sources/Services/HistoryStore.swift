import Foundation

/// 历史记录持久化（Codable JSON，零依赖；后续可换系统 sqlite3）。
/// 存 ~/Library/Application Support/SnapMind/history.json。
enum HistoryStore {
    private static var fileURL: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SnapMind", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    static func load() -> [CaptureRecord] {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([CaptureRecord].self, from: data)
        else { return [] }
        return list
    }

    static func save(_ list: [CaptureRecord]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        try? data.write(to: fileURL)
    }
}

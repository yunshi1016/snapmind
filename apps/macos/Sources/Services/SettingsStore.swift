import Foundation

/// 非密设置持久化（UserDefaults + JSON）。API Key 不在此，走 Keychain。
enum SettingsStore {
    private static let key = "appSettings.v1"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return .defaults }
        return s
    }

    static func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// 解析有效备份目录：留空用默认 ~/Library/Application Support/SnapMind/Screenshots。
    static func resolveBackupDir(_ configured: String) -> URL {
        let trimmed = configured.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            return URL(fileURLWithPath: trimmed, isDirectory: true)
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SnapMind/Screenshots", isDirectory: true)
    }
}

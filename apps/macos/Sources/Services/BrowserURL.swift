import AppKit

/// 取前台浏览器当前页 URL（Apple Events / AppleScript）。需「自动化」权限（每个浏览器各授权一次）。
/// 替代 Windows 的「浏览器扩展 + 本地 HTTP 服务」方案——macOS 原生、无需装扩展。
enum BrowserURL {
    /// Chromium 系：bundleId → AppleScript 应用名。
    private static let chromium: [String: String] = [
        "com.google.Chrome": "Google Chrome",
        "com.google.Chrome.canary": "Google Chrome Canary",
        "com.google.Chrome.beta": "Google Chrome Beta",
        "com.microsoft.edgemac": "Microsoft Edge",
        "com.brave.Browser": "Brave Browser",
        "com.vivaldi.Vivaldi": "Vivaldi",
        "com.operasoftware.Opera": "Opera",
        "company.thebrowser.Browser": "Arc",
    ]
    private static let safari: Set<String> = ["com.apple.Safari", "com.apple.SafariTechnologyPreview"]

    static func isBrowser(bundleId: String) -> Bool {
        chromium[bundleId] != nil || safari.contains(bundleId)
    }

    /// 若前台是已知浏览器，取其当前页 URL。失败/非 http 返回 ""。
    static func currentURL(bundleId: String) -> String {
        let script: String
        if let appName = chromium[bundleId] {
            script = "tell application \"\(appName)\" to return URL of active tab of front window"
        } else if safari.contains(bundleId) {
            script = "tell application \"Safari\" to return URL of front document"
        } else {
            return ""
        }

        var error: NSDictionary?
        guard let apple = NSAppleScript(source: script) else { return "" }
        let output = apple.executeAndReturnError(&error)
        if let error {
            Log.write("browserURL: AppleScript 失败 \(error[NSAppleScript.errorMessage] ?? "")")
            return ""
        }
        return normalize(output.stringValue ?? "")
    }

    /// 只接受 http/https；chrome://、空白页等忽略。
    private static func normalize(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = t.lowercased()
        return (lower.hasPrefix("http://") || lower.hasPrefix("https://")) ? t : ""
    }
}

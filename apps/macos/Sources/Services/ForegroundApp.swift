import AppKit
import CoreGraphics

/// 截图瞬间的前台窗口信息。
struct ForegroundInfo {
    var appName: String = ""
    var bundleId: String = ""
    var windowTitle: String = ""
    /// 浏览器当前页 URL（mM9，由 BrowserURL 填；非浏览器留空）。
    var url: String = ""
}

/// 取前台应用名/bundleId（NSWorkspace）+ 最前窗口标题（CGWindowList）。
/// 必须在弹出 SnapMind 自己的 UI **之前**调用，否则前台已变成我们自己。
enum ForegroundApp {
    static func capture() -> ForegroundInfo {
        var info = ForegroundInfo()
        guard let app = NSWorkspace.shared.frontmostApplication else { return info }
        info.appName = app.localizedName ?? ""
        info.bundleId = app.bundleIdentifier ?? ""
        info.windowTitle = frontWindowTitle(pid: app.processIdentifier) ?? ""
        return info
    }

    /// 该进程最前面普通窗口的标题。kCGWindowName 需屏幕录制权限（截图功能已要求，故可得）。
    private static func frontWindowTitle(pid: pid_t) -> String? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        // 列表按前后顺序，先命中该进程的 layer 0（普通窗口）即为最前窗口。
        for w in list {
            guard let owner = w[kCGWindowOwnerPID as String] as? pid_t, owner == pid else { continue }
            let layer = w[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { continue }
            if let name = w[kCGWindowName as String] as? String, !name.isEmpty {
                return name
            }
        }
        return nil
    }
}

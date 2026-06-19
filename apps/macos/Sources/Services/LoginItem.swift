import ServiceManagement

/// 开机自启（macOS 13+ SMAppService）。无状态命名空间。
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.write("loginItem: 切换失败 \(error.localizedDescription)")
        }
    }
}

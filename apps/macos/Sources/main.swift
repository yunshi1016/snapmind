import AppKit

// 经典 AppKit 入口：菜单栏常驻应用完全由 AppDelegate 掌控（窗口/状态项/生命周期）。
// 视图层仍用 SwiftUI，经 NSHostingController 承载。
let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.run()

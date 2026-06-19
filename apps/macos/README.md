<p align="center">
  <img src="assets/wordmark.png" alt="SnapMind · 瞬念" width="360">
</p>

# SnapMind for macOS（原生 SwiftUI）

SnapMind · 瞬念 的 macOS 原生版：全局快捷键 → 区域截图 → 批注「我的想法」→ AI 识别整理成结构化 Markdown → 写入本地 Obsidian Vault。Windows 版（Flutter，仓库 `yunshi1016/snapmind`）功能对齐，本端纯原生重写。

## 架构要点

- **本地优先、无后端**：AI 直接调云端 OpenAI 兼容多模态接口（默认 MiniMax），截图与 Obsidian 库都在本机。
- **零第三方依赖**：全用 Apple 系统框架（SwiftUI / AppKit / Carbon / Security / CoreGraphics / Foundation）。全局快捷键走 Carbon `RegisterEventHotKey`，历史用 Codable JSON 存储——不引入 SwiftPM 外部包。
- **菜单栏常驻**：`NSStatusItem` + 经典 AppKit 入口（`main.swift`），SwiftUI 视图经 `NSHostingController` 承载。
- **原生 macOS 取巧**：区域截图用系统 `screencapture -i`（系统原生框选器，省掉自绘 overlay）；浏览器来源 URL 用 Apple Events/AppleScript（省掉浏览器扩展 + 本地服务）。

## 构建与运行（无需 Xcode 工程）

```bash
./build.sh        # swiftc 直编 + 组 .app bundle + ad-hoc 签名 → build/SnapMind.app
./build.sh run    # 构建并启动
```

不依赖 XcodeGen / Xcode 工程 / SwiftPM 联网。`build.sh` 用 `swiftc` 编译 `Sources/` 下全部 `.swift`，手工组 `.app`，ad-hoc 签名。

### 用 Xcode 打开（可选）

仓库附 `project.yml`（XcodeGen 格式，仿 DriftMac 约定）。装了 XcodeGen 后 `xcodegen generate` 可产出 `.xcodeproj`。

## 权限（macOS）

- **屏幕录制**：截图必需。首次截图触发系统授权（系统设置 → 隐私与安全性 → 屏幕录制）。
- **自动化（Apple Events）**：取浏览器当前页 URL 时，对各浏览器各授权一次。
- 全局快捷键（Carbon）无需额外权限。

各权限失败都优雅降级，绝不阻塞截图主流程。

## 里程碑

mM0 脚手架+菜单栏 · mM1 设置+Keychain · mM2 Markdown→Obsidian · mM3 全局快捷键 · mM4 截图+区域选择 · mM5 批注窗 · mM6 闭环 · mM7 AI Vision · mM8 来源信息 · mM9 来源链接URL · mM10 历史 · mM11 打磨+打包

## 许可

GPL-3.0（与主仓库一致）。

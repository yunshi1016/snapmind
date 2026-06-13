<div align="center">

# SnapMind · 瞬念

**Capture your thoughts from anywhere.**

截图式第二大脑助手 —— 按下快捷键，框选屏幕，写下想法，AI 帮你整理成结构化 Markdown 笔记，直接写进你的 Obsidian 知识库。

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](./LICENSE)
![Platform](https://img.shields.io/badge/platform-Windows-informational)
![Status](https://img.shields.io/badge/status-v0.1-brightgreen)

</div>

---

## 这是什么

在任意 Windows 界面看到有价值的信息时：

1. 按全局快捷键（默认 **Ctrl+Shift+1**）
2. 框选一块屏幕区域
3. 弹出批注浮窗，写下「我的想法」
4. 点保存 —— 批注窗即收起、后台 AI 多模态识别截图内容，自动生成**标题 / 摘要 / 标签 / OCR 原文**，连同你的想法整理成一篇 Markdown 写入本地 **Obsidian Vault**，并留一份本地历史。

一句话：把「看到 → 截图 → 思考」这条最高频的捕捉动作，压缩成一次快捷键。

> 长期目标覆盖 **Windows / macOS / Android** 三端；当前第一版只做 Windows。

## 功能

- ⌨️ 全局快捷键（默认 `Ctrl+Shift+1`）在任意程序触发截图 + 全屏框选（自适配 DPI）
- ✍️ 截图后弹无边框批注浮窗，记录「我的想法」
- 🤖 AI 多模态识别：标题 + 摘要 + 标签 + OCR 原文（默认 **MiniMax**，OpenAI 兼容，可自由切换 provider）
  - 失败自动降级，断网/Key 失效也照常保存，**绝不丢笔记**
- 📝 生成 Markdown（YAML frontmatter + 纯内容，**不嵌截图**）写入 Vault
- 🧭 自动记录来源应用名 / 窗口标题
- 🖼️ 截图作可回看的临时备份（可选目录 + 保留时长，默认 7 天到期自动清理）
- 🗂️ 本地历史（SQLite）：列表回看，点击用 Obsidian 打开、可删
- 🪟 后台并发保存（最多 3 个）+ 右下角通知坞进度堆叠
- 🚀 系统托盘常驻 · 关窗隐藏到托盘 · 开机自启

详见 [docs/roadmap.md](./docs/roadmap.md)。

## 技术栈

Flutter + Dart（桌面）· Fluent UI（fluent_ui）· Riverpod · win32 (FFI) · leanflutter 生态（window_manager / hotkey_manager / tray_manager / screen_capturer）· dio（OpenAI 兼容 AI）· sqflite_common_ffi。

架构与模块设计见 [docs/architecture.md](./docs/architecture.md)。

## 仓库结构

```
snapmind/
├─ apps/desktop/        # Flutter 桌面应用（Windows 首发）
│  └─ lib/core/         # 纯 Dart 领域层：模型 / Markdown / Obsidian / AI（post-v1 抽到 packages/core）
├─ docs/                # 架构、路线图
├─ brand/               # 品牌 LOGO 源图与图标生成脚本产物
└─ .github/             # issue / PR 模板
```

## 开发环境

- **Flutter SDK**（stable）
- **Visual Studio 2022** + "使用 C++ 的桌面开发" 工作负载（Windows 桌面构建必需）
- 验证：`flutter doctor` 全绿

```bash
# 克隆后
cd apps/desktop
flutter pub get
flutter run -d windows
```

详细贡献流程见 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## AI 配置

应用内「设置」页填写即可（API Key 用系统安全存储，不落明文）：

- **Base URL** —— 默认 MiniMax，可改 OpenAI / DeepSeek / 通义 / 智谱 / 本地 Ollama 等任意 OpenAI 兼容端点
- **API Key**
- **Model** —— 必须是**多模态**模型（能读图）

脚本/集成测试用的环境变量样例见 [.env.example](./.env.example)。

## 路线图

`M0 脚手架 → … → M6 截图→批注→Markdown→Obsidian 闭环 → M7 AI → M8 来源 → M9 历史 → M10 打磨`。完整里程碑见 [docs/roadmap.md](./docs/roadmap.md)。

## 许可证

[GPL-3.0](./LICENSE) © SnapMind contributors

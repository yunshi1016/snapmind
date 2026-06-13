# 更新日志

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 格式，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [0.1.0] - 2026-06

首个可用版本（Windows）。完成「截图 → 批注 → AI 整理 → 写入 Obsidian」完整闭环。

### 新增

- 全局快捷键（默认 `Ctrl+Shift+1`）在任意程序触发截图
- 全屏框选截图（无边框 popup + setBounds，自适配 DPI 缩放）
- 截图后弹无边框批注浮窗，记录「我的想法」
- AI 多模态识别（OpenAI 兼容，默认 MiniMax）：自动生成标题 / 摘要 / 标签 / OCR 原文
  - 失败自动降级，断网或 Key 失效也照常保存，绝不丢笔记
- 按模板生成 Markdown（YAML frontmatter + 纯内容，不嵌截图）并写入 Obsidian Vault
- 来源信息：自动记录截图时的前台应用名与窗口标题（win32）
- 截图备份：可选目录 + 保留时长（默认 7 天，到期自动清理）
- 本地历史：SQLite 存储 + 历史列表页，点击用 Obsidian 打开、可删除
- 后台并发保存（最多 3 个）+ 右下角通知坞进度堆叠
- 系统托盘常驻、关窗隐藏到托盘、开机自启开关
- 设置页：Vault/目录、快捷键、AI 配置（provider 预设）、截图备份、开机自启

### 设计取舍

- UI 采用 Windows 11 Fluent 风格（fluent_ui）
- 笔记不嵌入截图，仅作可回看的临时备份
- 来源链接 URL 留待后续（需 UIAutomation 或浏览器扩展）
- 暂仅 Windows；架构为 macOS / Android 预留了平台抽象

# SnapMind 路线图

## 平台节奏

| 阶段 | 平台 | 状态 |
|---|---|---|
| v1 | Windows | 🚧 进行中 |
| v2 | macOS | 规划中 |
| v3 | Android | 规划中 |

技术栈一开始就为三端选型（Flutter + Dart），但 **v1 不为未来三端把首版做重**：平台相关能力都藏在接口背后，加端 = 加实现。

## v1 里程碑（Windows）

> 排序原则：闭环优先。先用桩打通数据流，再替换真能力。每个 M 可独立运行验收。

- **M0 脚手架** — monorepo 骨架；空窗口跑起来；托盘 + 关窗隐藏到托盘。
- **M1 设置** — Vault/Captures/Assets 目录、快捷键（默认 Ctrl+Shift+1）、AI 配置（默认 MiniMax，可自由切换）。
- **M2 Markdown→Obsidian** — 用硬编码样例写一篇 .md 到 Vault，验证模板/目录/内链。
- **M3 全局快捷键** — 注册快捷键，按下弹占位窗。
- **M4 截图 + 框选** — 抓全屏 → 透明 overlay → 框选 → 裁剪 → 存 PNG。
- **M5 批注窗** — 缩略图 + 「我的想法」+ 保存/取消。
- **M6 打通闭环（AI 用桩）** — 🎯 一次快捷键即可在 Obsidian 出带图笔记。
- **M7 AI Vision** — MiniMax 多模态填 ocr/title/summary/tags；失败降级不阻塞。
- **M8 来源信息** — win32 FFI 取应用名 + 窗口标题。
- **M9 历史** — sqflite_ffi 入库 + 历史列表页。
- **M10 打磨** — 开机自启、错误处理、多屏/DPI、msix 打包、文档。

## 未来（不进 v1）

- **本地 OCR**：用 Windows.Media.Ocr 离线识别，作为 Vision 之外的可选引擎（`OcrService` 接口已预留）。
- **云端 AI 网关**：把直连 AI API 抽象为自托管网关服务（这部分将容器化 / Docker，是 Docker 在本项目的合理边界）。
- **来源链接（sourceUrl）**：浏览器场景取当前 URL（UIAutomation 或浏览器扩展）。
- macOS / Android 端实现。

## 明确不做（v1）

macOS/Android 客户端、视频录制、音频转写、账号系统、云同步、知识图谱、浏览器插件、商业化计费、客户端 Docker 化。

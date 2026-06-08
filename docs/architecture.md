# SnapMind 架构

> 本文档随实现演进。当前对应 v1（Windows）。

## 设计原则

- **闭环优先**：先打通 截图 → 批注 → Markdown → Obsidian，再逐层加 AI、来源、历史。
- **接口在 core，平台实现在 desktop/platform**：跨端能复用的纯逻辑放 `packages/core`；依赖插件 / FFI / 平台的放 `apps/desktop`。未来加 macOS/Android 只新增实现 + 改依赖注入绑定，core 不动。
- **不过度设计**：v1 只切 `apps/desktop` + `packages/core` 两个包；melos 等真有第三个包再引入。

## 分层

```
┌─────────────────────────────────────────────┐
│ apps/desktop  (Flutter UI + 平台实现 + DI)    │
│  features/: capture · annotate · settings · history
│  platform/windows/: win32 FFI · capturer 封装 · 存储后端
└───────────────┬─────────────────────────────┘
                │ 依赖（实现 core 定义的接口）
┌───────────────▼─────────────────────────────┐
│ packages/core  (纯 Dart，无 Flutter 依赖)     │
│  models/ · services/(接口) · markdown/ · obsidian/ · ai/
└─────────────────────────────────────────────┘
```

## 模块

| 模块 | 职责 | 落点 |
|---|---|---|
| SettingsService | Vault/目录/快捷键/AI 配置读写；Key 走 secure_storage | core 接口 + desktop 存储 |
| HotkeyService | 注册全局快捷键，触发捕获 | desktop（hotkey_manager） |
| CaptureService | 抓全屏 → overlay 框选 → 裁剪 → 存 PNG | desktop + screen_capturer/image |
| ForegroundWindowService | 取前台应用名 + 窗口标题 | desktop（win32 FFI） |
| OcrService | 识别接口；v1 实现复用 AiService 的 Vision | core 接口 + ai 实现 |
| AiService | OpenAI 兼容多模态：图+批注 → ocr/title/summary/tags；含超时/重试/降级 | core（dio） |
| MarkdownGenerator | 模板渲染 CaptureRecord → Markdown（含 `![[...]]`） | core（纯函数） |
| ObsidianWriter | .md 落 Captures（建目录、处理重名）；截图**不进 Vault**，由备份逻辑另存外部目录 | core（dart:io） |
| RetentionSweeper | 启动时清理备份目录中超过保留期的截图 | core 接口 + desktop |
| HistoryService | 记录入库 + 查询列表 | core 接口 + desktop(sqflite_ffi) |

## 跨端 Dart vs 平台原生

| 纯 Dart（core，三端复用） | 平台原生（每端单独实现接口） |
|---|---|
| CaptureRecord 模型/枚举 | HotkeyService（hotkey_manager） |
| MarkdownGenerator | 屏幕抓取（screen_capturer） |
| ObsidianWriter | ForegroundWindowService（win32 FFI，仅 Win） |
| AiService / OcrService 实现 | 托盘/窗口/overlay（tray/window_manager） |
| Settings/History 业务逻辑与接口 | 存储后端（sqflite_ffi / secure_storage） |

> v1 的「原生」几乎全是现成插件 + 一段 win32 FFI，自写原生代码量 ≈ 0。

## 数据模型 CaptureRecord

`id`(uuid) · `createdAt` · `screenshotPath`(备份路径，到期后可能已被清理) · `vaultPath` · `markdownPath` · `userNote` · `ocrText` · `aiTitle` · `aiSummary` · `tags`(List) · `sourceApp` · `sourceWindowTitle` · `sourceUrl`(可空，v1 留空) · `sourceType`(enum，v1 仅 `screenshot`) · `status`(enum：`draft/saving/saved/aiFailed`)。

## 捕获时序（关键）

1. 快捷键触发 → **先**取前台窗口元数据（overlay 一弹焦点就丢，必须先取）。
2. 抓全屏 PNG（多屏按 screen_retriever 几何/DPI 处理）。
3. 起无边框/透明/置顶/全屏 overlay 窗显示截图，GestureDetector 框选矩形。
4. 松手 → 裁剪 → 存 PNG 到 Assets → 关 overlay。
5. 弹批注窗：缩略图 + 「我的想法」+ 保存/取消。
6. 保存 → 组 Record → **AI 异步**填字段（失败降级：title=批注首行，status=aiFailed，不阻塞）→ MarkdownGenerator → ObsidianWriter 写盘 → HistoryService 入库 → 成功提示。

## Markdown 模板

```markdown
# {{title}}

## 我的想法
{{user_note}}

## AI 摘要
{{summary}}

## OCR 原文
{{ocr_text}}

## 来源信息
- 应用：{{source_app}}
- 窗口标题：{{source_window_title}}
- 来源链接：{{source_url}}
- 时间：{{created_at}}

## 标签
{{tags}}
```

> **截图不嵌入笔记**（v1 决策）：笔记是纯内容，无 `![[截图]]`。截图作为可回看的临时备份另存到一个**可在 Vault 之外**的文件夹（`screenshotBackupDir`，留空=默认 `%LOCALAPPDATA%\SnapMind\Screenshots`），按 `screenshotRetentionDays`（默认 7 天；0=用完即删，-1=永久）到期自动清理。

## 架构决策（ADR 摘要）

- **选 Flutter 而非 Electron/Tauri/MAUI/纯原生**：一套代码覆盖三端含移动；桌面工具所需的全局快捷键/透明 overlay/屏幕抓取在 Flutter 生态最成熟。
- **AI Vision 而非本地 OCR（v1）**：一次多模态调用同时出 OCR+标题+摘要+标签，几乎不写原生代码；`OcrService` 接口可替换，未来可换本地 Windows OCR。
- **win32 FFI 而非 C# helper**：纯 Dart 直调 Win32 取窗口元数据，省掉独立进程与 IPC。

详细 ADR 见 [docs/adr/](./adr/)。

# 贡献指南

感谢你对 SnapMind 的兴趣！本文档说明如何搭建开发环境并参与贡献。

## 开发环境

- **Flutter SDK**（stable 通道，3.44+）
- **Visual Studio 2022/2026** + 「使用 C++ 的桌面开发」工作负载（Windows 桌面构建必需）
- 验证：`flutter doctor` 中 Flutter 与 Visual Studio 两项为绿

```bash
git clone <repo-url> snapmind
cd snapmind/apps/desktop
flutter pub get
flutter run -d windows
```

## 项目结构

```
apps/desktop/
├─ lib/
│  ├─ main.dart            # 入口：窗口/托盘/热键/DI 初始化
│  ├─ app.dart            # 应用外壳 + 截图/批注/通知坞 窗口状态机
│  ├─ core/               # 纯 Dart 领域层（模型 / Markdown / Obsidian / AI）
│  ├─ features/           # capture · annotate · home · history · settings
│  ├─ services/           # 平台服务：热键 / 截图 / 前台窗口(win32) / 设置 / 历史
│  └─ providers.dart      # Riverpod 装配
└─ test/                  # 纯逻辑单元测试
```

更详细的架构与关键设计见 [docs/architecture.md](docs/architecture.md)。

## 提交前检查

```bash
flutter analyze        # 必须零 issue
flutter test           # 必须全绿
dart format lib test   # 统一格式
```

## 约定

- 分支：`feature/xxx`、`fix/xxx`
- Commit：简洁说明「做了什么、为什么」，正文可分点
- 平台相关能力（截图/热键/窗口/win32）放 `services/` 或 features 的平台实现；可跨端复用的纯逻辑放 `core/`
- 涉及窗口管理改动，务必先读 [docs/architecture.md](docs/architecture.md) 里的「窗口管理踩坑记录」——这块在 Windows 上很容易翻车

## 行为准则

参与本项目即表示你同意遵守 [行为准则](CODE_OF_CONDUCT.md)。

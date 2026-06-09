import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'features/home/home_page.dart';
import 'features/settings/settings_page.dart';
import 'providers.dart';
import 'services/hotkey_service.dart';
import 'theme.dart';

class SnapMindApp extends StatelessWidget {
  const SnapMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'SnapMind',
      debugShowCheckedModeBanner: false,
      theme: buildSnapMindDarkTheme(),
      home: const RootShell(),
    );
  }
}

/// 应用外壳：左侧 Fluent 导航 + 系统托盘 + 关窗隐藏到托盘 + 全局快捷键。
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell>
    with WindowListener, TrayListener {
  final HotkeyService _hotkeys = HotkeyService();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initTray();
    _registerHotkey(ref.read(settingsProvider).hotkey);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    _hotkeys.unregister();
    super.dispose();
  }

  Future<void> _initTray() async {
    await trayManager.setIcon('assets/tray_icon.ico');
    await trayManager.setToolTip('SnapMind · 瞬念');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: '显示 SnapMind'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: '退出'),
        ],
      ),
    );
  }

  Future<void> _registerHotkey(String hotkeyString) async {
    try {
      await _hotkeys.register(hotkeyString, onTriggered: _onHotkeyTriggered);
    } catch (e) {
      if (!mounted) return;
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('快捷键注册失败'),
          content: Text('可能已被其他程序占用：$e'),
          severity: InfoBarSeverity.warning,
          onClose: close,
        ),
      );
    }
  }

  // M3 占位：按下快捷键 → 唤出窗口 + 提示。M4 会替换为「开始截图」。
  Future<void> _onHotkeyTriggered() async {
    await _show();
    if (!mounted) return;
    setState(() => _index = 0);
    await displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: const Text('🎯 全局快捷键触发成功'),
        content: const Text('截图捕捉将在 M4 接入。'),
        severity: InfoBarSeverity.success,
        onClose: close,
      ),
    );
  }

  @override
  void onWindowClose() async {
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }

  @override
  void onTrayIconMouseDown() => _show();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await _show();
        break;
      case 'quit':
        await _quit();
        break;
    }
  }

  Future<void> _show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quit() async {
    await _hotkeys.unregister();
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    // 设置里的快捷键变更时，重新注册。
    ref.listen<String>(
      settingsProvider.select((s) => s.hotkey),
      (prev, next) {
        if (prev != next) _registerHotkey(next);
      },
    );

    return NavigationView(
      pane: NavigationPane(
        selected: _index,
        onChanged: (i) => setState(() => _index = i),
        displayMode: PaneDisplayMode.compact,
        items: [
          PaneItem(
            icon: const Icon(FluentIcons.home),
            title: const Text('主页'),
            body: HomePage(onOpenSettings: () => setState(() => _index = 1)),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.settings),
            title: const Text('设置'),
            body: const SettingsPage(),
          ),
        ],
      ),
    );
  }
}

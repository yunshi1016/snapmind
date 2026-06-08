import 'package:fluent_ui/fluent_ui.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'features/home/home_page.dart';
import 'features/settings/settings_page.dart';
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

/// 应用外壳：左侧 Fluent 导航 + 系统托盘 + 关窗隐藏到托盘。
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WindowListener, TrayListener {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initTray();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
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
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
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

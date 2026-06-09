import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'features/capture/capture_overlay.dart';
import 'features/capture/capture_session.dart';
import 'features/home/home_page.dart';
import 'features/settings/settings_page.dart';
import 'providers.dart';
import 'services/capture_service.dart';
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
  bool _capturing = false;

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

  // M4：按下快捷键 → 抓全屏 → 全屏 overlay 框选。窗口尺寸切换都在隐藏态完成，避免闪烁。
  Future<void> _onHotkeyTriggered() async {
    if (_capturing) return;
    _capturing = true;
    try {
      if (await windowManager.isVisible()) {
        await windowManager.hide();
        await Future.delayed(const Duration(milliseconds: 220));
      }
      final shot = await const CaptureService().captureFullScreen();
      if (shot == null) {
        await _resetWindowHidden();
        _capturing = false;
        await _showError('截图失败', '未获取到屏幕图像');
        return;
      }
      // 仍隐藏：先切全屏置顶，再挂会话，最后一次性 show —— 不露出主界面、不闪烁。
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setFullScreen(true);
      ref.read(captureSessionProvider.notifier).start(
            CaptureSession(
              imagePath: shot.path,
              imageWidth: shot.width,
              imageHeight: shot.height,
            ),
          );
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      ref.read(captureSessionProvider.notifier).end();
      await _resetWindowHidden();
      _capturing = false;
      await _showError('截图出错', '$e');
    }
  }

  /// 退出全屏、恢复正常尺寸（不改变可见性）。
  Future<void> _resetWindowHidden() async {
    await windowManager.setFullScreen(false);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSize(const Size(900, 640));
    await windowManager.center();
  }

  // 框选完成 → 裁剪 → 存备份目录。M5 将改为弹批注窗。
  Future<void> _completeCapture(Rect logicalRect, Size canvasSize) async {
    // 先隐藏窗口，再做尺寸恢复，避免主界面在全屏下一闪。
    await windowManager.hide();
    final session = ref.read(captureSessionProvider);
    ref.read(captureSessionProvider.notifier).end();
    await _resetWindowHidden();

    String message;
    bool ok = false;
    try {
      if (session == null) {
        message = '会话丢失';
      } else {
        final scaleX = session.imageWidth / canvasSize.width;
        final scaleY = session.imageHeight / canvasSize.height;
        final x = (logicalRect.left * scaleX).round().clamp(0, session.imageWidth - 1);
        final y = (logicalRect.top * scaleY).round().clamp(0, session.imageHeight - 1);
        final w = (logicalRect.width * scaleX).round().clamp(1, session.imageWidth - x);
        final h = (logicalRect.height * scaleY).round().clamp(1, session.imageHeight - y);
        final backupCfg = ref.read(settingsProvider).screenshotBackupDir;
        final res = await const CaptureService().cropAndSaveToBackup(
          sourcePath: session.imagePath,
          x: x,
          y: y,
          width: w,
          height: h,
          backupDirConfigured: backupCfg,
        );
        ok = true;
        message = '已截取 ${res.width}×${res.height}，保存：\n${res.path}';
      }
    } catch (e) {
      message = '裁剪/保存失败：$e';
    }

    _capturing = false;
    await _show();
    if (!mounted) return;
    setState(() => _index = 0);
    await displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: Text(ok ? '✂️ 截取成功 (M4)' : '截取失败'),
        content: Text(message),
        severity: ok ? InfoBarSeverity.success : InfoBarSeverity.error,
        onClose: close,
      ),
    );
  }

  Future<void> _cancelCapture() async {
    await windowManager.hide(); // 先隐藏避免闪烁
    ref.read(captureSessionProvider.notifier).end();
    await _resetWindowHidden();
    _capturing = false;
  }

  Future<void> _showError(String title, String content) async {
    await _show();
    if (!mounted) return;
    await displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: Text(title),
        content: Text(content),
        severity: InfoBarSeverity.error,
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

    final session = ref.watch(captureSessionProvider);

    return Stack(
      children: [
        NavigationView(
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
        ),
        if (session != null)
          Positioned.fill(
            child: CaptureOverlay(
              imagePath: session.imagePath,
              imageWidth: session.imageWidth,
              imageHeight: session.imageHeight,
              onComplete: _completeCapture,
              onCancel: _cancelCapture,
            ),
          ),
      ],
    );
  }
}

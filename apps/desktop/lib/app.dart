import 'dart:io';
import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';

import 'core/markdown/markdown_generator.dart';
import 'core/models/capture_record.dart';
import 'core/obsidian/obsidian_writer.dart';
import 'features/annotate/annotation.dart';
import 'features/annotate/annotation_modal.dart';
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
  bool _savingAnnotation = false;

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
        // 轮询直到窗口确实隐藏，再加 settle，绝不把 SnapMind 自己拍进截图。
        var tries = 0;
        while (tries < 20 && await windowManager.isVisible()) {
          await Future.delayed(const Duration(milliseconds: 25));
          tries++;
        }
        await Future.delayed(const Duration(milliseconds: 150));
      }
      final shot = await const CaptureService().captureFullScreen();
      if (shot == null) {
        await _resetWindowHidden();
        _capturing = false;
        await _showError('截图失败', '未获取到屏幕图像');
        return;
      }
      // 预加载截图进图像缓存：overlay 首帧即显示截图，不闪主界面。
      if (mounted) {
        await precacheImage(FileImage(File(shot.path)), context);
      }
      ref.read(captureSessionProvider.notifier).start(
            CaptureSession(
              imagePath: shot.path,
              imageWidth: shot.width,
              imageHeight: shot.height,
            ),
          );
      final entered = await _enterCaptureWindow(shot);
      if (!entered) {
        // Flutter 视图没能同步到全屏尺寸 —— 自动安全退出，绝不停在死界面。
        ref.read(captureSessionProvider.notifier).end();
        await windowManager.hide();
        await _restoreNormalChrome();
        _capturing = false;
        await _showError('截图窗口异常', '选区窗口未能铺满屏幕，已安全退出，请重试。');
        return;
      }
    } catch (e) {
      ref.read(captureSessionProvider.notifier).end();
      await _resetWindowHidden();
      _capturing = false;
      await _showError('截图出错', '$e');
    }
  }

  /// 进入全屏选区窗口：无边框 setBounds 铺满主屏（不用 setFullScreen —— 它会出现
  /// 原生窗口已全屏、Flutter 视图却没跟着变的不同步，正是「界面假死/选区只有窗口大」的根因）。
  /// 轮询 Flutter 视图的物理尺寸，确认真的铺满才返回 true。
  Future<bool> _enterCaptureWindow(FullScreenShot shot) async {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final dpr = view.devicePixelRatio;
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.setResizable(false);

    final log = StringBuffer()
      ..writeln('--- ${DateTime.now()} dpr=$dpr '
          'shot=${shot.width}x${shot.height} ---');

    // 业界做法（Snipaste/PixPin 类工具）：选区窗是 WS_POPUP 纯无边框窗口，
    // 客户区 == 屏幕像素，精确匹配。setAsFrameless 去掉 resize 边框（hidden
    // titlebar 会留 ~16px 边框导致偏差）。宽容差仅作极端机型兜底，不再是主判定。
    await windowManager.setAsFrameless();
    await windowManager
        .setBounds(Rect.fromLTWH(0, 0, shot.width / dpr, shot.height / dpr));
    await windowManager.show();
    await windowManager.focus();
    var fallbackOk = false;
    for (var i = 0; i < 60; i++) {
      final ps = view.physicalSize;
      if (i == 0 || i == 59) log.writeln('i=$i physical=$ps');
      if ((ps.width - shot.width).abs() <= 2) {
        log.writeln('OK exact i=$i physical=$ps');
        _writeDiag(log);
        await windowManager.setAlwaysOnTop(true);
        return true;
      }
      fallbackOk = (ps.width - shot.width).abs() <= 80;
      await Future.delayed(const Duration(milliseconds: 25));
    }
    if (fallbackOk) {
      log.writeln('OK fallback physical=${view.physicalSize}');
      _writeDiag(log);
      await windowManager.setAlwaysOnTop(true);
      return true;
    }
    try {
      log.writeln('FAIL physical=${view.physicalSize} '
          'nativeBounds=${await windowManager.getBounds()}');
    } catch (_) {}
    _writeDiag(log);
    return false;
  }

  void _writeDiag(StringBuffer log) {
    try {
      final tmp = Platform.environment['TEMP'] ?? '.';
      File('$tmp\\snapmind_diag.log')
          .writeAsStringSync(log.toString(), mode: FileMode.append);
    } catch (_) {}
  }

  /// 退出最大化/全屏、恢复正常窗口样式与尺寸（不改变可见性）。
  Future<void> _resetWindowHidden() async {
    await windowManager.unmaximize();
    await windowManager.setFullScreen(false);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setResizable(true);
    await windowManager.setTitleBarStyle(
      TitleBarStyle.normal,
      windowButtonVisibility: true,
    );
    await windowManager.setSize(const Size(900, 640));
    await windowManager.center();
  }

  /// 进入「批注浮窗」：无边框、置顶、紧凑居中，只显示批注卡片，不弹整个主窗。
  Future<void> _enterAnnotationWindow() async {
    await windowManager.unmaximize();
    await windowManager.setFullScreen(false);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setResizable(false);
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.setSize(const Size(480, 580));
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
  }

  /// 恢复正常主窗 chrome 与尺寸（不改变可见性）。
  Future<void> _restoreNormalChrome() async {
    await windowManager.unmaximize();
    await windowManager.setFullScreen(false);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setResizable(true);
    await windowManager.setTitleBarStyle(
      TitleBarStyle.normal,
      windowButtonVisibility: true,
    );
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

    if (session == null) {
      _capturing = false;
      await _showError('截取失败', '会话丢失');
      return;
    }
    try {
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
      // 裁剪完成 → 进入批注。
      ref.read(annotationProvider.notifier).start(
            PendingCapture(
              croppedPng: Uint8List.fromList(res.pngBytes),
              screenshotPath: res.path,
              width: res.width,
              height: res.height,
              createdAt: DateTime.now(),
            ),
          );
      _capturing = false;
      await _enterAnnotationWindow();
    } catch (e) {
      _capturing = false;
      await _showError('截取失败', '$e');
    }
  }

  // M5+M6：保存批注 → 生成 Markdown → 写入 Obsidian（闭环）。
  Future<void> _saveAnnotation(String note) async {
    final pending = ref.read(annotationProvider);
    if (pending == null) return;
    final settings = ref.read(settingsProvider);
    if (!settings.isConfigured) {
      await _showError('未配置知识库', '请先在「设置」里填写 Obsidian Vault 路径再保存。');
      return;
    }
    setState(() => _savingAnnotation = true);

    String message;
    bool ok = false;
    try {
      final record = CaptureRecord(
        id: const Uuid().v4(),
        createdAt: pending.createdAt,
        userNote: note,
        screenshotPath: pending.screenshotPath,
        vaultPath: settings.vaultPath,
      );
      final markdown = const MarkdownGenerator().generate(record);
      final now = pending.createdAt;
      String two(int n) => n.toString().padLeft(2, '0');
      final dateStr =
          '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}${two(now.minute)}';
      final res = await const ObsidianWriter().writeNote(
        vaultPath: settings.vaultPath,
        capturesDir: settings.capturesDir,
        baseName: '$dateStr ${record.displayTitle}',
        markdown: markdown,
      );
      ok = true;
      message = '笔记已写入：${res.fileName}';
    } catch (e) {
      message = '写入失败：$e';
    }

    if (!mounted) return;
    if (ok) {
      // 浮窗内短暂确认，然后静默回托盘（笔记已在 Obsidian）。
      await displayInfoBar(
        context,
        duration: const Duration(milliseconds: 1100),
        builder: (context, close) => InfoBar(
          title: const Text('✅ 已保存到 Obsidian'),
          content: Text(message),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
      await windowManager.hide();
      ref.read(annotationProvider.notifier).clear();
      if (mounted) setState(() => _savingAnnotation = false);
      await _restoreNormalChrome();
    } else {
      setState(() => _savingAnnotation = false);
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('保存失败'),
          content: Text(message),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
    }
  }

  Future<void> _cancelAnnotation() async {
    final pending = ref.read(annotationProvider);
    ref.read(annotationProvider.notifier).clear();
    // 取消则删除孤立的截图备份。
    if (pending != null) {
      try {
        await File(pending.screenshotPath).delete();
      } catch (_) {}
    }
    await windowManager.hide();
    await _restoreNormalChrome();
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
      // 关窗时清理进行中的截图/批注，避免重开残留 overlay；标题栏 ✕ 也成了一条逃生路。
      ref.read(captureSessionProvider.notifier).end();
      ref.read(annotationProvider.notifier).clear();
      _capturing = false;
      await _restoreNormalChrome();
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
    final pending = ref.watch(annotationProvider);

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
        if (pending != null)
          Positioned.fill(
            child: AnnotationModal(
              pending: pending,
              onSave: _saveAnnotation,
              onCancel: _cancelAnnotation,
              saving: _savingAnnotation,
            ),
          ),
      ],
    );
  }
}

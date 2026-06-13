import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';

import 'core/ai/ai_service.dart';
import 'core/markdown/markdown_generator.dart';
import 'models/app_settings.dart';
import 'core/models/capture_record.dart';
import 'core/obsidian/obsidian_writer.dart';
import 'features/annotate/annotation.dart';
import 'features/annotate/annotation_modal.dart';
import 'features/capture/capture_overlay.dart';
import 'features/capture/capture_session.dart';
import 'features/history/history_page.dart';
import 'features/home/home_page.dart';
import 'features/settings/settings_page.dart';
import 'providers.dart';
import 'services/capture_service.dart';
import 'services/foreground_window_service.dart';
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
  ForegroundWindowInfo _lastSource = const ForegroundWindowInfo();

  // 后台保存任务（AI+写盘+入库，不占窗口）。最多 3 个并发。
  final List<_SaveJob> _jobs = [];
  int _jobSeq = 0;
  bool _syncing = false;
  bool _syncPending = false;

  static const int _maxConcurrent = 3;
  int get _runningJobs =>
      _jobs.where((j) => j.status == _JobStatus.running).length;

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
    // 正在框选/批注（窗口独占态）时拒绝新触发，避免窗口形态打架。
    if (_capturing ||
        ref.read(captureSessionProvider) != null ||
        ref.read(annotationProvider) != null) {
      return;
    }
    // 后台保存已达并发上限：提示用户稍候，不进截图。
    if (_runningJobs >= _maxConcurrent) {
      final bid = _jobSeq++;
      setState(
        () => _jobs.add(
          _SaveJob(
            id: bid,
            label: '最多同时处理 $_maxConcurrent 条，请等一条完成',
            status: _JobStatus.blocked,
          ),
        ),
      );
      await _syncWindow();
      Timer(const Duration(milliseconds: 1800), () => _removeJob(bid));
      return;
    }
    _capturing = true;
    try {
      // 最先取前台窗口元数据 —— 一旦动了自己的窗口，焦点就变了。
      _lastSource = const ForegroundWindowService().capture();
      // 最小化窗口的 SetWindowPos 会被系统忽略（导致后续 setBounds 失效）——先还原。
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
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
      ref
          .read(captureSessionProvider.notifier)
          .start(
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
      ..writeln(
        '--- ${DateTime.now()} dpr=$dpr '
        'shot=${shot.width}x${shot.height} ---',
      );

    // 业界做法（Snipaste/PixPin 类工具）：选区窗是 WS_POPUP 纯无边框窗口，
    // 客户区 == 屏幕像素，精确匹配。setAsFrameless 去掉 resize 边框（hidden
    // titlebar 会留 ~16px 边框导致偏差）。宽容差仅作极端机型兜底，不再是主判定。
    await windowManager.setAsFrameless();
    await windowManager.setBounds(
      Rect.fromLTWH(0, 0, shot.width / dpr, shot.height / dpr),
    );
    await windowManager.show();
    await windowManager.focus();
    var fallbackOk = false;
    for (var i = 0; i < 60; i++) {
      // 偶发 setBounds 未生效（如刚从最小化还原）——中途重发兜底。
      if (i == 15 || i == 35) {
        await windowManager.setBounds(
          Rect.fromLTWH(0, 0, shot.width / dpr, shot.height / dpr),
        );
        log.writeln('re-apply bounds at i=$i');
      }
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
      log.writeln(
        'FAIL physical=${view.physicalSize} '
        'nativeBounds=${await windowManager.getBounds()}',
      );
    } catch (_) {}
    _writeDiag(log);
    return false;
  }

  void _writeDiag(StringBuffer log) {
    if (!kDebugMode) return; // 仅调试构建写诊断日志，发布版不污染用户 TEMP。
    try {
      final tmp = Platform.environment['TEMP'] ?? '.';
      File(
        '$tmp\\snapmind_diag.log',
      ).writeAsStringSync(log.toString(), mode: FileMode.append);
    } catch (_) {}
  }

  /// 统一窗口状态机：根据 批注/通知坞/空闲 切到对应形态（截图流程自己管窗口，不插手）。
  /// 防重入：同步进行中再次请求会在循环里补一次，保证最终状态正确。
  Future<void> _syncWindow() async {
    if (_syncing) {
      _syncPending = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncPending = false;
        await _applyWindowState();
      } while (_syncPending);
    } finally {
      // 即使某步窗口操作抛异常也要释放锁，否则窗口同步永久卡死。
      _syncing = false;
    }
  }

  Future<void> _applyWindowState() async {
    if (_capturing) return; // 截图流程独占窗口
    final pending = ref.read(annotationProvider);
    if (pending != null) {
      await _enterAnnotationWindow();
    } else if (_jobs.isNotEmpty) {
      await _enterDock();
    } else {
      await _restoreNormalChrome();
      await windowManager.hide();
    }
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

  /// 批注浮窗：无边框、置顶、紧凑居中。
  Future<void> _enterAnnotationWindow() async {
    await windowManager.unmaximize();
    await windowManager.setFullScreen(false);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setResizable(false);
    await windowManager.setMinimumSize(const Size(1, 1));
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.setSize(const Size(480, 580));
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
  }

  /// 通知坞：右下角无边框小窗，高度随任务条数。后台保存进度/结果在这里堆叠显示。
  Future<void> _enterDock() async {
    await windowManager.unmaximize();
    await windowManager.setFullScreen(false);
    await windowManager.setResizable(false);
    await windowManager.setMinimumSize(const Size(1, 1));
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    final n = _jobs.length;
    final height = 20.0 + n * 64.0; // 少量 buffer，避免无边框客户区误差导致溢出
    await windowManager.setSize(Size(360, height));
    await windowManager.setAlignment(Alignment.bottomRight);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.show();
  }

  /// 恢复正常主窗 chrome 与尺寸（不改变可见性）。
  Future<void> _restoreNormalChrome() async {
    await windowManager.unmaximize();
    await windowManager.setFullScreen(false);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setMinimumSize(const Size(720, 560));
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
      final x = (logicalRect.left * scaleX).round().clamp(
        0,
        session.imageWidth - 1,
      );
      final y = (logicalRect.top * scaleY).round().clamp(
        0,
        session.imageHeight - 1,
      );
      final w = (logicalRect.width * scaleX).round().clamp(
        1,
        session.imageWidth - x,
      );
      final h = (logicalRect.height * scaleY).round().clamp(
        1,
        session.imageHeight - y,
      );
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
      ref
          .read(annotationProvider.notifier)
          .start(
            PendingCapture(
              croppedPng: Uint8List.fromList(res.pngBytes),
              screenshotPath: res.path,
              width: res.width,
              height: res.height,
              createdAt: DateTime.now(),
              sourceApp: _lastSource.app,
              sourceWindowTitle: _lastSource.title,
            ),
          );
      _capturing = false;
      await _syncWindow(); // pending 已设 → 进批注窗
    } catch (e) {
      _capturing = false;
      await _showError('截取失败', '$e');
    }
  }

  // 保存：建后台任务 → 立即收起批注窗（释放窗口，可马上截下一张）→ 后台 AI+写盘+入库。
  Future<void> _saveAnnotation(String note) async {
    final pending = ref.read(annotationProvider);
    if (pending == null) return;
    final settings = ref.read(settingsProvider);
    if (!settings.isConfigured) {
      await _showError('未配置知识库', '请先在「设置」里填写 Obsidian Vault 路径再保存。');
      return;
    }
    final jobId = _jobSeq++;
    setState(
      () => _jobs.add(
        _SaveJob(
          id: jobId,
          label: _jobLabel(note, pending),
          status: _JobStatus.running,
        ),
      ),
    );
    ref.read(annotationProvider.notifier).clear();
    await _syncWindow(); // pending 清空、有 job → 进通知坞
    unawaited(_runSaveJob(jobId, pending, note, settings));
  }

  String _jobLabel(String note, PendingCapture p) {
    final first = note.trim().split('\n').first.trim();
    if (first.isNotEmpty) return first;
    return p.sourceApp.isNotEmpty ? '来自 ${p.sourceApp}' : '新捕获';
  }

  Future<void> _runSaveJob(
    int jobId,
    PendingCapture pending,
    String note,
    AppSettings settings,
  ) async {
    // AI 识别（失败降级，绝不阻塞写盘）。
    AiCaptureResult? ai;
    String? aiError;
    try {
      final apiKey = await ref.read(settingsServiceProvider).readApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        aiError = '未配置 API Key';
      } else {
        ai = await AiService(
          baseUrl: settings.aiBaseUrl,
          apiKey: apiKey,
          model: settings.aiModel,
        ).analyzeCapture(pngBytes: pending.croppedPng, userNote: note);
      }
    } catch (e) {
      aiError = e is DioException
          ? (e.response != null
                ? 'HTTP ${e.response?.statusCode}: ${e.response?.data}'
                : e.message ?? '$e')
          : '$e';
    }

    var ok = false;
    String detail;
    try {
      final record = CaptureRecord(
        id: const Uuid().v4(),
        createdAt: pending.createdAt,
        userNote: note,
        screenshotPath: pending.screenshotPath,
        vaultPath: settings.vaultPath,
        ocrText: ai?.ocrText ?? '',
        aiTitle: ai?.title ?? '',
        aiSummary: ai?.summary ?? '',
        tags: ai?.tags ?? const [],
        sourceApp: pending.sourceApp,
        sourceWindowTitle: pending.sourceWindowTitle,
        status: ai != null ? CaptureStatus.saved : CaptureStatus.aiFailed,
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
      await ref
          .read(historyServiceProvider)
          .add(record.copyWith(markdownPath: res.markdownPath));
      ref.invalidate(historyListProvider);
      // 保留时长为 0（用完即删）：写完笔记即删除该截图备份。
      if (settings.screenshotRetentionDays == 0) {
        try {
          await File(pending.screenshotPath).delete();
        } catch (_) {}
      }
      ok = true;
      detail = ai != null
          ? record.displayTitle
          : '${record.displayTitle}（AI 未生效）';
      if (ai == null) {
        _writeDiag(
          StringBuffer()..writeln('${DateTime.now()} AI fail: $aiError'),
        );
      }
    } catch (e) {
      detail = '写入失败：$e';
    }

    _updateJob(jobId, ok ? _JobStatus.done : _JobStatus.failed, detail);
    // 成功停留 2s、失败停留 5s 后移除。
    await Future.delayed(Duration(seconds: ok ? 2 : 5));
    _removeJob(jobId);
  }

  void _updateJob(int id, _JobStatus status, String detail) {
    if (!mounted) return;
    setState(() {
      for (final j in _jobs) {
        if (j.id == id) {
          j.status = status;
          j.detail = detail;
        }
      }
    });
  }

  void _removeJob(int id) {
    if (!mounted) return;
    setState(() => _jobs.removeWhere((j) => j.id == id));
    _syncWindow(); // 条数变化 → 调整坞尺寸；空了 → 隐藏
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
    await _syncWindow(); // 无 pending → 通知坞 或 隐藏
  }

  Future<void> _cancelCapture() async {
    await windowManager.hide(); // 先隐藏避免闪烁
    ref.read(captureSessionProvider.notifier).end();
    await _resetWindowHidden();
    _capturing = false;
    await _syncWindow(); // 有后台任务则回通知坞，否则保持隐藏
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
    // 等后台保存任务跑完再退出，避免丢笔记（上限 70s，覆盖 AI 60s 超时 + 写盘）。
    var waited = 0;
    while (_runningJobs > 0 && waited < 70000) {
      await Future.delayed(const Duration(milliseconds: 200));
      waited += 200;
    }
    await _hotkeys.unregister();
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    // 设置里的快捷键变更时，重新注册。
    ref.listen<String>(settingsProvider.select((s) => s.hotkey), (prev, next) {
      if (prev != next) _registerHotkey(next);
    });

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
                body: HomePage(
                  onOpenSettings: () => setState(() => _index = 2),
                ),
              ),
              PaneItem(
                icon: const Icon(FluentIcons.history),
                title: const Text('历史'),
                body: const HistoryPage(),
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
            ),
          ),
        if (session == null && pending == null && _jobs.isNotEmpty)
          Positioned.fill(child: _NotificationDock(jobs: List.of(_jobs))),
      ],
    );
  }
}

enum _JobStatus { running, done, failed, blocked }

/// 一个后台保存任务（可变：状态/详情会原地更新）。
class _SaveJob {
  _SaveJob({
    required this.id,
    required this.label,
    required this.status,
    // ignore: unused_element_parameter
    this.detail = '',
  });

  final int id;
  final String label;
  _JobStatus status;
  String detail;
}

/// 右下角通知坞：竖向堆叠最多几条后台保存任务的进度/结果，铺满坞窗口。
class _NotificationDock extends StatelessWidget {
  const _NotificationDock({required this.jobs});

  final List<_SaveJob> jobs;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0E0E12),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final j in jobs)
            Padding(
              padding: const EdgeInsets.all(4),
              child: _JobCard(job: j),
            ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final _SaveJob job;

  @override
  Widget build(BuildContext context) {
    final running = job.status == _JobStatus.running;
    final failed = job.status == _JobStatus.failed;
    final blocked = job.status == _JobStatus.blocked;
    final title = job.detail.isNotEmpty ? job.detail : job.label;

    Widget leading;
    if (running) {
      leading = const SizedBox(
        width: 18,
        height: 18,
        child: ProgressRing(strokeWidth: 2.5),
      );
    } else if (blocked) {
      leading = const Icon(
        FluentIcons.warning,
        size: 18,
        color: Color(0xFFFBBF24),
      );
    } else if (failed) {
      leading = const Icon(
        FluentIcons.error_badge,
        size: 18,
        color: Color(0xFFF87171),
      );
    } else {
      leading = const Icon(
        FluentIcons.completed_solid,
        size: 18,
        color: Color(0xFF4ADE80),
      );
    }

    return Container(
      height: 56,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF17171D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  running
                      ? 'AI 识别并保存中…'
                      : (blocked ? '请稍候' : (failed ? '保存失败' : '已保存到 Obsidian')),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

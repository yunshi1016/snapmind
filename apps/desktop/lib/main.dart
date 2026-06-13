import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'providers.dart';
import 'services/history_service.dart';

/// SnapMind · 瞬念 — Capture your thoughts from anywhere.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  // 清理可能残留的全局热键注册（热重启/崩溃后）。
  await hotKeyManager.unregisterAll();
  final prefs = await SharedPreferences.getInstance();
  final history = await HistoryService.open();

  const windowOptions = WindowOptions(
    size: Size(900, 640),
    minimumSize: Size(720, 560),
    center: true,
    title: 'SnapMind',
    backgroundColor: Color(0xFF101014), // 不透明，避免无边框浮窗透出背后内容/闪烁
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // 关闭窗口时不退出进程，改为隐藏到托盘。
  await windowManager.setPreventClose(true);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        historyServiceProvider.overrideWithValue(history),
      ],
      child: const SnapMindApp(),
    ),
  );
}

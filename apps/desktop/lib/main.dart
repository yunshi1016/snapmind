import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'providers.dart';

/// SnapMind · 瞬念 — Capture your thoughts from anywhere.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  const windowOptions = WindowOptions(
    size: Size(900, 640),
    minimumSize: Size(720, 560),
    center: true,
    title: 'SnapMind',
    backgroundColor: Colors.transparent,
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
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const SnapMindApp(),
    ),
  );
}

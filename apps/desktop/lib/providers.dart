import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/app_settings.dart';
import 'services/settings_service.dart';

/// 由 main() 通过 override 注入真实实例。
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('在 main() 中用 overrideWithValue 注入'),
);

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final settingsServiceProvider = Provider<SettingsService>(
  (ref) => SettingsService(
    ref.watch(sharedPreferencesProvider),
    ref.watch(secureStorageProvider),
  ),
);

/// 当前应用设置（不含 API Key）。
class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsServiceProvider).load();

  Future<void> save(AppSettings next) async {
    await ref.read(settingsServiceProvider).save(next);
    state = next;
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

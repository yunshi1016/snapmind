import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// 设置持久化：普通设置走 SharedPreferences，API Key 走系统安全存储。
class SettingsService {
  SettingsService(this._prefs, this._secure);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const String _kSettings = 'snapmind.settings.json';
  static const String _kApiKey = 'snapmind.ai.apiKey';

  AppSettings load() {
    final raw = _prefs.getString(_kSettings);
    if (raw == null || raw.isEmpty) return AppSettings.defaults();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppSettings.defaults();
    }
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setString(_kSettings, jsonEncode(settings.toJson()));
  }

  Future<String?> readApiKey() => _secure.read(key: _kApiKey);

  Future<void> writeApiKey(String value) {
    if (value.isEmpty) return _secure.delete(key: _kApiKey);
    return _secure.write(key: _kApiKey, value: value);
  }
}

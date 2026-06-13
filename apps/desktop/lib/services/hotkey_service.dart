import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// 注册/注销全局快捷键。解析 "Ctrl+Shift+1" 这类字符串；解析失败回退到默认 Ctrl+Shift+1。
class HotkeyService {
  HotKey? _current;

  /// 当前实际注册的快捷键（用于在 UI 展示规范化结果）。
  HotKey? get current => _current;

  Future<void> register(
    String hotkeyString, {
    required void Function() onTriggered,
  }) async {
    await unregister();
    final hotKey = _parse(hotkeyString) ?? _defaultHotKey();
    _current = hotKey;
    await hotKeyManager.register(hotKey, keyDownHandler: (_) => onTriggered());
  }

  Future<void> unregister() async {
    final hk = _current;
    if (hk != null) {
      await hotKeyManager.unregister(hk);
      _current = null;
    }
  }

  HotKey _defaultHotKey() => HotKey(
    key: PhysicalKeyboardKey.digit1,
    modifiers: const [HotKeyModifier.control, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );

  HotKey? _parse(String input) {
    final parts = input
        .split('+')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;

    final modifiers = <HotKeyModifier>[];
    PhysicalKeyboardKey? key;
    for (final p in parts) {
      switch (p) {
        case 'ctrl':
        case 'control':
          modifiers.add(HotKeyModifier.control);
        case 'shift':
          modifiers.add(HotKeyModifier.shift);
        case 'alt':
        case 'option':
          modifiers.add(HotKeyModifier.alt);
        case 'win':
        case 'meta':
        case 'cmd':
        case 'super':
          modifiers.add(HotKeyModifier.meta);
        default:
          key = _keyMap[p];
      }
    }
    if (key == null || modifiers.isEmpty) return null;
    return HotKey(key: key, modifiers: modifiers, scope: HotKeyScope.system);
  }

  static final Map<String, PhysicalKeyboardKey> _keyMap = {
    '0': PhysicalKeyboardKey.digit0,
    '1': PhysicalKeyboardKey.digit1,
    '2': PhysicalKeyboardKey.digit2,
    '3': PhysicalKeyboardKey.digit3,
    '4': PhysicalKeyboardKey.digit4,
    '5': PhysicalKeyboardKey.digit5,
    '6': PhysicalKeyboardKey.digit6,
    '7': PhysicalKeyboardKey.digit7,
    '8': PhysicalKeyboardKey.digit8,
    '9': PhysicalKeyboardKey.digit9,
    'a': PhysicalKeyboardKey.keyA,
    'b': PhysicalKeyboardKey.keyB,
    'c': PhysicalKeyboardKey.keyC,
    'd': PhysicalKeyboardKey.keyD,
    'e': PhysicalKeyboardKey.keyE,
    'f': PhysicalKeyboardKey.keyF,
    'g': PhysicalKeyboardKey.keyG,
    'h': PhysicalKeyboardKey.keyH,
    'i': PhysicalKeyboardKey.keyI,
    'j': PhysicalKeyboardKey.keyJ,
    'k': PhysicalKeyboardKey.keyK,
    'l': PhysicalKeyboardKey.keyL,
    'm': PhysicalKeyboardKey.keyM,
    'n': PhysicalKeyboardKey.keyN,
    'o': PhysicalKeyboardKey.keyO,
    'p': PhysicalKeyboardKey.keyP,
    'q': PhysicalKeyboardKey.keyQ,
    'r': PhysicalKeyboardKey.keyR,
    's': PhysicalKeyboardKey.keyS,
    't': PhysicalKeyboardKey.keyT,
    'u': PhysicalKeyboardKey.keyU,
    'v': PhysicalKeyboardKey.keyV,
    'w': PhysicalKeyboardKey.keyW,
    'x': PhysicalKeyboardKey.keyX,
    'y': PhysicalKeyboardKey.keyY,
    'z': PhysicalKeyboardKey.keyZ,
  };
}

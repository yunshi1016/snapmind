import 'package:fluent_ui/fluent_ui.dart';

/// SnapMind 品牌主色（紫）。
const Color kBrandColor = Color(0xFF7C6CF0);

/// Windows 11 Fluent 深色主题。
FluentThemeData buildSnapMindDarkTheme() {
  final accent = kBrandColor.toAccentColor();
  return FluentThemeData(
    brightness: Brightness.dark,
    accentColor: accent,
    scaffoldBackgroundColor: const Color(0xFF101014),
    visualDensity: VisualDensity.standard,
    focusTheme: FocusThemeData(
      glowFactor: 0,
      primaryBorder: BorderSide(width: 2, color: accent.normal),
    ),
  );
}

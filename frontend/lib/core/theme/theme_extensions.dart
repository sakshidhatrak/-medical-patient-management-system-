import 'package:flutter/material.dart';

extension ThemeColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // Backgrounds
  Color get bgColor       => isDark ? const Color(0xFF171629) : const Color(0xFFF8F6F2);
  Color get cardColor     => isDark ? const Color(0xFF211E38) : Colors.white;
  Color get inputColor    => isDark ? const Color(0xFF2C2948) : const Color(0xFFECEAE4);
  Color get surfaceVar    => isDark ? const Color(0xFF2A2745) : const Color(0xFFECEAE4);

  // Text
  Color get textPrimary   => isDark ? const Color(0xFFEEECFF) : const Color(0xFF302D28);
  Color get textSecondary => isDark ? const Color(0xFFB8B5DC) : const Color(0xFF6E6A63);
  Color get textDisabled  => isDark ? const Color(0xFF7B789E) : const Color(0xFF979088);

  // Borders
  Color get borderColor   => isDark ? const Color(0xFF3D3A62) : const Color(0xFFE0DDD7);
  Color get dividerColor  => isDark ? const Color(0xFF2E2B50) : const Color(0xFFECEAE4);

  // Primary surface (for icon backgrounds, etc.)
  Color get primarySurf   => isDark ? const Color(0xFF3D3A62) : const Color(0xFFE8EBF8);
}

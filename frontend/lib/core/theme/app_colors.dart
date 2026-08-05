import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Primary indigo ────────────────────────────────────────────────────────
  static const Color primary        = Color(0xFF4B55CC);
  static const Color primaryLight   = Color(0xFF7882D9);
  static const Color primaryDark    = Color(0xFF3D47B4);
  static const Color primarySurface = Color(0xFFE8EBF8);
  static const Color onPrimary      = Colors.white;

  // ── Sidebar / dark surfaces ───────────────────────────────────────────────
  static const Color sidebarBg         = Color(0xFF1E1C19);
  static const Color sidebarItemActive  = Color(0xFF4B55CC);
  static const Color sidebarItemHover   = Color(0xFF2A2825);
  static const Color sidebarText        = Color(0xFF7A776F);
  static const Color sidebarTextActive  = Colors.white;

  // ── Dark card ─────────────────────────────────────────────────────────────
  static const Color darkCard    = Color(0xFF2A2825);
  static const Color darkCardAlt = Color(0xFF1E1C19);

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color background     = Color(0xFFF8F6F2);
  static const Color surface        = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFECEAE4);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color success        = Color(0xFF2D7A4E);
  static const Color successSurface = Color(0xFFDEEDE6);
  static const Color warning        = Color(0xFF74633E);
  static const Color warningSurface = Color(0xFFEDE4CB);
  static const Color error          = Color(0xFF8A4430);
  static const Color errorSurface   = Color(0xFFF0E4DE);
  static const Color info           = Color(0xFF4B55CC);
  static const Color infoSurface    = Color(0xFFE8EBF8);

  // ── Blood type chip colors ────────────────────────────────────────────────
  static const Color bloodTypeA  = Color(0xFF8A4430);
  static const Color bloodTypeB  = Color(0xFF74633E);
  static const Color bloodTypeO  = Color(0xFF2D7A4E);
  static const Color bloodTypeAB = Color(0xFF4B55CC);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF302D28);
  static const Color textSecondary = Color(0xFF6E6A63);
  static const Color textDisabled  = Color(0xFF979088);
  static const Color textInverse   = Colors.white;

  // ── Border / Divider ─────────────────────────────────────────────────────
  static const Color border  = Color(0xFFE0DDD7);
  static const Color divider = Color(0xFFECEAE4);
}

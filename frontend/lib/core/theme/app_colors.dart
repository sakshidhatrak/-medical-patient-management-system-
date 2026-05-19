import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Primary purple ───────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF9D97FF);
  static const Color primaryDark = Color(0xFF4A43CC);
  static const Color primarySurface = Color(0xFFEEEDFF);
  static const Color onPrimary = Colors.white;

  // ── Sidebar ──────────────────────────────────────────────────────────────
  static const Color sidebarBg = Color(0xFF1A1D2E);
  static const Color sidebarItemActive = Color(0xFF6C63FF);
  static const Color sidebarItemHover = Color(0xFF252A45);
  static const Color sidebarText = Color(0xFF8A8EAD);
  static const Color sidebarTextActive = Colors.white;

  // ── Dark card (used in profile panels, modals) ───────────────────────────
  static const Color darkCard = Color(0xFF252A45);
  static const Color darkCardAlt = Color(0xFF1E2139);

  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF5F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F0F9);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF00C48C);
  static const Color successSurface = Color(0xFFE0FAF3);
  static const Color warning = Color(0xFFFFCF5C);
  static const Color warningSurface = Color(0xFFFFF8E1);
  static const Color error = Color(0xFFFF647C);
  static const Color errorSurface = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF0095FF);
  static const Color infoSurface = Color(0xFFE3F2FD);

  // ── Blood type chip colors ────────────────────────────────────────────────
  static const Color bloodTypeA = Color(0xFFFF647C);
  static const Color bloodTypeB = Color(0xFFFFCF5C);
  static const Color bloodTypeO = Color(0xFF00C48C);
  static const Color bloodTypeAB = Color(0xFF6C63FF);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1D2E);
  static const Color textSecondary = Color(0xFF8A8EAD);
  static const Color textDisabled = Color(0xFFBDBDD9);
  static const Color textInverse = Colors.white;

  // ── Border / Divider ─────────────────────────────────────────────────────
  static const Color border = Color(0xFFEAEAF5);
  static const Color divider = Color(0xFFF0F0F9);
}

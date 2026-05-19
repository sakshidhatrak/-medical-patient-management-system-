import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTypography {
  // Resolved font family name used by the google_fonts package.
  // Referenced by all inline TextStyle objects so they match the theme.
  static final String fontFamily = GoogleFonts.inter().fontFamily!;

  // Full Material 3 text theme backed by Google Fonts Inter.
  static TextTheme get textTheme => GoogleFonts.interTextTheme();
}

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary — "Trust Anchor" deep blue
  static const Color primary = Color(0xFF0040A1);
  static const Color primaryLight = Color(0xFF0056D2);
  static const Color primaryDark = Color(0xFF002D7A);

  // Progress green — "Momentum Signal"
  static const Color accent = Color(0xFF006E2A);
  static const Color accentLight = Color(0xFF5CFD80);
  static const Color accentContainer = Color(0xFF006E35);

  // Surfaces — light
  static const Color surface = Color(0xFFFAF8FF);
  static const Color surfaceLow = Color(0xFFF2F3FE);
  static const Color surfaceLowest = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFD9D9E4);

  // Surfaces — dark
  static const Color darkBg = Color(0xFF12131A);
  static const Color darkSurface = Color(0xFF1E2030);
  static const Color darkCard = Color(0xFF262840);
  static const Color darkBorder = Color(0xFF363850);

  // Legacy aliases (used widely across screens)
  static const Color lightBg = surfaceLow;
  static const Color lightSurface = surfaceLowest;
  static const Color lightCard = surfaceLowest;
  static const Color lightBorder = surfaceDim;

  // Text
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textLight = Color(0xFF6B7280);
  static const Color textDark = Color(0xFF191B23);
  static const Color textMuted = Color(0xFF9CA3AF);

  // Semantic
  static const Color success = Color(0xFF006E2A);
  static const Color successLight = Color(0xFF5CFD80);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF0056D2);

  // Misc
  static const Color star = Color(0xFFF59E0B);
  static const Color escrow = Color(0xFF7C3AED);
  static const Color urgent = Color(0xFFDC2626);

  // Gradient helpers
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentContainer],
  );
}

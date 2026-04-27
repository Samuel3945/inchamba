import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary — verde trabajo y crecimiento
  static const Color primary = Color(0xFF1A8C52);
  static const Color primaryLight = Color(0xFF22AA63);
  static const Color primaryDark = Color(0xFF136640);

  // Accent (complementario)
  static const Color accent = Color(0xFF136640);
  static const Color accentLight = Color(0xFF6EE7A0);
  static const Color accentContainer = Color(0xFF1A8C52);

  // Surfaces — light (tinte verde muy sutil)
  static const Color surface = Color(0xFFF8FBF9);
  static const Color surfaceLow = Color(0xFFF2F7F4);
  static const Color surfaceLowest = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFD3E4DA);

  // Surfaces — dark
  static const Color darkBg = Color(0xFF111915);
  static const Color darkSurface = Color(0xFF1A2620);
  static const Color darkCard = Color(0xFF22302A);
  static const Color darkBorder = Color(0xFF2E4038);

  // Legacy aliases
  static const Color lightBg = surfaceLow;
  static const Color lightSurface = surfaceLowest;
  static const Color lightCard = surfaceLowest;
  static const Color lightBorder = surfaceDim;

  // Text
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textLight = Color(0xFF6B7280);
  static const Color textDark = Color(0xFF14211A);
  static const Color textMuted = Color(0xFF9CA3AF);

  // Semantic
  static const Color success = Color(0xFF1A8C52);
  static const Color successLight = Color(0xFF6EE7A0);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF0369A1);

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
    colors: [primaryDark, primary],
  );
}

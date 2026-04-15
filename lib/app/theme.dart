import 'package:flutter/material.dart';

/// Google Stitch design tokens for BJJ Open Mat Finder
class StitchTokens {
  // Colors
  static const primary = Color(0xFF1A1A2E);
  static const secondary = Color(0xFFE94560);
  static const accent = Color(0xFF16C79A);
  static const surfaceLight = Color(0xFFF5F5F7);
  static const surfaceDark = Color(0xFF0F0F23);
  static const warning = Color(0xFFF7B731);
  static const error = Color(0xFFEB3B5A);
  static const textSecondary = Color(0xFF6B7280);
  static const glassBg = Color(0x14FFFFFF);
  static const glassBorder = Color(0x26FFFFFF);

  // Spacing
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Radius
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusPill = 9999;

  // Animation
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);
  static const Curve curveDefault = Curves.easeInOutCubic;
  static const Curve curveBounce = Curves.elasticOut;
}

/// Belt rank colors
class BeltColors {
  static const white = Color(0xFFF5F5F5);
  static const blue = Color(0xFF2196F3);
  static const purple = Color(0xFF9C27B0);
  static const brown = Color(0xFF795548);
  static const black = Color(0xFF212121);

  static Color fromRank(String rank) {
    switch (rank.toLowerCase()) {
      case 'blue': return blue;
      case 'purple': return purple;
      case 'brown': return brown;
      case 'black': return black;
      default: return white;
    }
  }
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: StitchTokens.primary,
        brightness: Brightness.light,
        primary: StitchTokens.primary,
        secondary: StitchTokens.secondary,
        tertiary: StitchTokens.accent,
        surface: StitchTokens.surfaceLight,
        error: StitchTokens.error,
      ),
      scaffoldBackgroundColor: StitchTokens.surfaceLight,
      fontFamily: 'Inter',
      textTheme: _textTheme(Brightness.light),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StitchTokens.radiusLg),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: StitchTokens.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StitchTokens.radiusMd),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StitchTokens.radiusMd),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: StitchTokens.primary,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: StitchTokens.primary,
        brightness: Brightness.dark,
        primary: StitchTokens.secondary,
        secondary: StitchTokens.accent,
        surface: StitchTokens.surfaceDark,
        error: StitchTokens.error,
      ),
      scaffoldBackgroundColor: StitchTokens.surfaceDark,
      fontFamily: 'Inter',
      textTheme: _textTheme(Brightness.dark),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StitchTokens.radiusLg),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: StitchTokens.secondary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StitchTokens.radiusMd),
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final color = brightness == Brightness.light
        ? StitchTokens.primary
        : StitchTokens.surfaceLight;

    return TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: color),
      headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: color),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: color),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: color),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: color),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: color),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color),
      bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: StitchTokens.textSecondary),
    );
  }
}

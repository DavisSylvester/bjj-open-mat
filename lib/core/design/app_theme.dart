import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

class AppTheme {
  static ThemeData sport() {
    final t = AppTokens.sport();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: t.bg,
      colorScheme: ColorScheme.dark(
        primary: t.red,
        secondary: t.amber,
        tertiary: t.green,
        surface: t.surface,
        error: t.red,
        onPrimary: Colors.white,
        onSurface: t.text,
      ),
      extensions: [t],
      fontFamily: GoogleFonts.barlowCondensed().fontFamily,
      textTheme: GoogleFonts.barlowCondensedTextTheme(ThemeData.dark().textTheme).copyWith(
        bodyMedium: GoogleFonts.barlow(color: t.body),
        bodySmall: GoogleFonts.barlow(color: t.muted),
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(),
        margin: EdgeInsets.zero,
      ),
      dividerColor: t.border,
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg2,
        foregroundColor: t.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.barlowCondensed(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: t.text,
          letterSpacing: 0.02,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: t.bg2,
        selectedItemColor: t.text,
        unselectedItemColor: t.muted,
        elevation: 0,
      ),
    );
  }

  static ThemeData glass() {
    final t = AppTokens.glass();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: t.bg,
      colorScheme: ColorScheme.light(
        primary: t.red,
        secondary: t.green,
        surface: t.bg,
        error: t.red,
        onPrimary: Colors.white,
        onSurface: t.text,
      ),
      extensions: [t],
      fontFamily: GoogleFonts.barlow().fontFamily,
      textTheme: GoogleFonts.barlowTextTheme(ThemeData.light().textTheme).copyWith(
        bodyMedium: GoogleFonts.barlow(color: t.body),
        bodySmall: GoogleFonts.barlow(color: t.muted),
      ),
      cardTheme: CardThemeData(
        color: const Color(0x8CFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerColor: t.border,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: t.text,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}

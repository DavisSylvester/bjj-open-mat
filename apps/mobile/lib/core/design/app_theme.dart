import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

class AppTheme {
  static ThemeData glass() {
    final t = AppTokens.glass();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: t.bg,
      colorScheme: ColorScheme.light(
        primary: t.primary,
        secondary: t.green,
        surface: t.bg,
        error: t.red,
        onPrimary: Colors.white,
        onSurface: t.text,
      ),
      extensions: [t],
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme).copyWith(
        bodyMedium: GoogleFonts.plusJakartaSans(color: t.body),
        bodySmall: GoogleFonts.plusJakartaSans(color: t.muted),
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

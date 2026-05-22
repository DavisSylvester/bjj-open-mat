import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OMColors {
  // Brand
  static const crimson     = Color(0xFFE94560);
  static const crimsonHot  = Color(0xFFFF5A75);
  static const crimsonDeep = Color(0xFFB6243A);
  static const teal        = Color(0xFF16C79A);
  static const tealDeep    = Color(0xFF0E8C6B);

  // Gi types
  static const gi   = Color(0xFF2196F3);
  static const noGi = Color(0xFFFF9800);
  static const both = Color(0xFF9C27B0);

  // Experience levels
  static const allLevels    = Color(0xFF16C79A);
  static const beginner     = Color(0xFF3DDC84);
  static const intermediate = Color(0xFFFF9800);
  static const advanced     = Color(0xFFE94560);

  // Background / surfaces (light glass theme)
  static const bg           = Color(0xFFF4F1EC);
  static const bgSoft       = Color(0x8CFFFFFF);
  static const surface      = Color(0x8CFFFFFF);   // rgba(255,255,255,0.55)
  static const surfaceHi    = Color(0xC8FFFFFF);   // rgba(255,255,255,0.78)
  static const surfaceSolid = Color(0xFFFFFFFF);
  static const border       = Color(0xA6FFFFFF);   // inner highlight rgba(255,255,255,0.65)
  static const borderHi     = Color(0xD9FFFFFF);   // rgba(255,255,255,0.85)
  static const borderDark   = Color(0x12141428);   // outer hairline rgba(20,20,40,0.07)

  // Text
  static const text  = Color(0xFF0F1430);
  static const body  = Color(0xBF0F1430);   // rgba(15,20,48,0.75)
  static const muted = Color(0x8C0F1430);   // rgba(15,20,48,0.55)
  static const faint = Color(0x590F1430);   // rgba(15,20,48,0.35)

  // Accents
  static const star = Color(0xFFFFC857);
}

class OMSpacing {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;
}

// Backward-compat alias so existing screens keep compiling
class StitchTokens {
  static const primary      = OMColors.text;
  static const secondary    = OMColors.crimson;
  static const accent       = OMColors.teal;
  static const surfaceLight = OMColors.bg;
  static const surfaceDark  = Color(0xFF0F0F23);
  static const warning      = Color(0xFFF7B731);
  static const error        = Color(0xFFEB3B5A);
  static const textSecondary = OMColors.muted;
  static const glassBg      = OMColors.surface;
  static const glassBorder  = OMColors.border;

  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 16;
  static const double lg   = 24;
  static const double xl   = 32;
  static const double xxl  = 48;

  static const double radiusSm  = 8;
  static const double radiusMd  = 12;
  static const double radiusLg  = 16;
  static const double radiusXl  = 24;
  static const double radiusPill = 9999;

  static const Duration durationFast   = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow   = Duration(milliseconds: 500);
  static const Curve curveDefault = Curves.easeInOutCubic;
  static const Curve curveBounce  = Curves.elasticOut;
}

class BeltColors {
  static const white  = Color(0xFFF5F5F5);
  static const blue   = Color(0xFF1E5BC9);
  static const purple = Color(0xFF6A2A9A);
  static const brown  = Color(0xFF6B3A1A);
  static const black  = Color(0xFF0A0A0A);

  static const Map<String, Map<String, Color>> beltData = {
    'white':  {'bg': Color(0xFFF5F5F5), 'stripe': Color(0xFF1A1A2E), 'fg': Color(0xFF1A1A2E)},
    'blue':   {'bg': Color(0xFF1E5BC9), 'stripe': Color(0xFF0D2E6B), 'fg': Color(0xFFFFFFFF)},
    'purple': {'bg': Color(0xFF6A2A9A), 'stripe': Color(0xFF2A0D45), 'fg': Color(0xFFFFFFFF)},
    'brown':  {'bg': Color(0xFF6B3A1A), 'stripe': Color(0xFF2E1808), 'fg': Color(0xFFFFFFFF)},
    'black':  {'bg': Color(0xFF0A0A0A), 'stripe': Color(0xFFE94560), 'fg': Color(0xFFFFFFFF)},
  };

  static Color fromRank(String rank) {
    switch (rank.toLowerCase()) {
      case 'blue':   return blue;
      case 'purple': return purple;
      case 'brown':  return brown;
      case 'black':  return black;
      default:       return white;
    }
  }
}

TextStyle _display({double size = 32, Color color = OMColors.text, double letterSpacing = 0.01}) =>
    GoogleFonts.barlowCondensed(
      fontWeight: FontWeight.w700,
      fontSize: size,
      color: color,
      letterSpacing: letterSpacing,
      height: 1.0,
    );

TextStyle _barlow({double size = 14, FontWeight weight = FontWeight.w400, Color color = OMColors.text}) =>
    GoogleFonts.barlow(fontWeight: weight, fontSize: size, color: color);

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: OMColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: OMColors.crimson,
        brightness: Brightness.light,
        primary: OMColors.crimson,
        secondary: OMColors.teal,
        surface: OMColors.bg,
        error: const Color(0xFFEB3B5A),
      ),
      textTheme: TextTheme(
        displayLarge:  _display(size: 32),
        headlineLarge: _display(size: 28),
        headlineMedium: _display(size: 22),
        titleLarge:    _display(size: 18),
        titleMedium:   _barlow(size: 16, weight: FontWeight.w600),
        bodyLarge:     _barlow(size: 16),
        bodyMedium:    _barlow(size: 14),
        bodySmall:     _barlow(size: 13, color: OMColors.muted),
        labelLarge:    _barlow(size: 14, weight: FontWeight.w600),
        labelSmall:    _display(size: 11, letterSpacing: 0.12),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: OMColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: OMColors.crimson,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OMColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OMColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OMColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OMColors.crimson, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: OMColors.text,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: const Color(0x1FE94560),
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
          _display(
            size: 10,
            color: states.contains(WidgetState.selected) ? OMColors.crimson : OMColors.muted,
            letterSpacing: 0.12,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? OMColors.crimson : OMColors.muted,
          size: 22,
        )),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: OMColors.surface,
        selectedColor: OMColors.crimson.withValues(alpha: 0.15),
        side: const BorderSide(color: OMColors.borderDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: _display(size: 11, letterSpacing: 0.1),
      ),
    );
  }

  static ThemeData dark() => light();
}

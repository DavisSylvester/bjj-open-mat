import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTokens extends ThemeExtension<AppTokens> {
  final Color bg;
  final Color bg2;
  final Color surface;
  final Color surfaceHi;
  final Color border;
  final Color borderHi;
  final Color text;
  final Color body;
  final Color muted;
  final Color faint;
  final Color primary;
  final Color panel;
  final Color gold;
  final Color red;
  final Color amber;
  final Color green;
  final Color gi;
  final Color noGi;
  final Color both;
  final Color allLevels;
  final Color beginner;
  final Color intermediate;
  final Color advanced;
  final Map<String, Color> beltBg;
  final Map<String, Color> beltFg;
  final TextStyle displayStyle;
  final TextStyle h1Style;
  final TextStyle h2Style;
  final TextStyle labelStyle;
  final TextStyle miniStyle;
  final TextStyle numStyle;
  final TextStyle bodyStyle;
  final bool isSport;
  final double cardRadius;
  final double badgeRadius;

  const AppTokens({
    required this.bg,
    required this.bg2,
    required this.surface,
    required this.surfaceHi,
    required this.border,
    required this.borderHi,
    required this.text,
    required this.body,
    required this.muted,
    required this.faint,
    required this.primary,
    required this.panel,
    required this.gold,
    required this.red,
    required this.amber,
    required this.green,
    required this.gi,
    required this.noGi,
    required this.both,
    required this.allLevels,
    required this.beginner,
    required this.intermediate,
    required this.advanced,
    required this.beltBg,
    required this.beltFg,
    required this.displayStyle,
    required this.h1Style,
    required this.h2Style,
    required this.labelStyle,
    required this.miniStyle,
    required this.numStyle,
    required this.bodyStyle,
    required this.isSport,
    required this.cardRadius,
    required this.badgeRadius,
  });

  factory AppTokens.sport() {
    final display = GoogleFonts.barlowCondensed(
      fontWeight: FontWeight.w800,
      letterSpacing: 0.02,
      height: 0.95,
    );
    return AppTokens(
      bg: const Color(0xFF070C1F),
      bg2: const Color(0xFF0B1330),
      surface: const Color(0xFF101A3A),
      surfaceHi: const Color(0xFF16244A),
      border: const Color(0xFF1B2A52),
      borderHi: const Color(0xFF2A3D6B),
      text: const Color(0xFFFFFFFF),
      body: const Color(0xFFC7D3F0),
      muted: const Color(0xFF7286B0),
      faint: const Color(0xFF3F5085),
      primary: const Color(0xFFFF2244),
      panel: const Color(0xFF101A3A),
      gold: const Color(0xFFFFC107),
      red: const Color(0xFFFF2244),
      amber: const Color(0xFFFFC107),
      green: const Color(0xFF00E599),
      gi: const Color(0xFF2196F3),
      noGi: const Color(0xFFFF9800),
      both: const Color(0xFFB061FF),
      allLevels: const Color(0xFF00E599),
      beginner: const Color(0xFF3DDC84),
      intermediate: const Color(0xFFFFC107),
      advanced: const Color(0xFFFF2244),
      beltBg: const {
        'white': Color(0xFFE5E5E5),
        'blue': Color(0xFF1E5BC9),
        'purple': Color(0xFF7A2BB5),
        'brown': Color(0xFF6B3A1A),
        'black': Color(0xFF0A0A0A),
      },
      beltFg: const {
        'white': Color(0xFF0B1330),
        'blue': Color(0xFFFFFFFF),
        'purple': Color(0xFFFFFFFF),
        'brown': Color(0xFFFFFFFF),
        'black': Color(0xFFFFFFFF),
      },
      displayStyle: display.copyWith(fontSize: 22, color: const Color(0xFFFFFFFF)),
      h1Style: display.copyWith(fontSize: 32, color: const Color(0xFFFFFFFF)),
      h2Style: display.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.05,
        color: const Color(0xFFFFFFFF),
      ),
      labelStyle: display.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.18,
        color: const Color(0xFF7286B0),
      ),
      miniStyle: display.copyWith(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.16,
        color: const Color(0xFF7286B0),
      ),
      numStyle: display.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        color: const Color(0xFFFFFFFF),
      ),
      bodyStyle: GoogleFonts.barlow(
        fontWeight: FontWeight.w500,
        fontSize: 13,
        color: const Color(0xFFC7D3F0),
      ),
      isSport: true,
      cardRadius: 0,
      badgeRadius: 0,
    );
  }

  factory AppTokens.glass() {
    final display = GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800);
    final body = GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500);
    return AppTokens(
      bg:        const Color(0xFFFFFFFF),
      bg2:       const Color(0xFFF5F6FA),
      surface:   const Color(0xFFFFFFFF),
      surfaceHi: const Color(0xFFF5F6FA),
      border:    const Color(0xFFECEDF2),
      borderHi:  const Color(0xFFE0E2EA),
      text:      const Color(0xFF14151A),
      body:      const Color(0xFF3D4150),
      muted:     const Color(0xFF6B7280),
      faint:     const Color(0xFFB9BDC9),
      primary:   const Color(0xFF5B53F2),
      panel:     const Color(0xFFF5F6FA),
      gold:      const Color(0xFFFFB020),
      red:       const Color(0xFFFF5470),
      amber:     const Color(0xFFFFB020),
      green:     const Color(0xFF10B981),
      gi:        const Color(0xFF2E7BFF),
      noGi:      const Color(0xFFFF7A33),
      both:      const Color(0xFF8B5CF6),
      allLevels: const Color(0xFF10B981),
      beginner:  const Color(0xFF34D399),
      intermediate: const Color(0xFFFFB020),
      advanced:  const Color(0xFFFF5470),
      beltBg: const {
        'white':  Color(0xFFD7D9E0),
        'blue':   Color(0xFF2E7BFF),
        'purple': Color(0xFF8B5CF6),
        'brown':  Color(0xFF8B5A2B),
        'black':  Color(0xFF1A1B22),
      },
      beltFg: const {
        'white':  Color(0xFF14151A),
        'blue':   Color(0xFFFFFFFF),
        'purple': Color(0xFFFFFFFF),
        'brown':  Color(0xFFFFFFFF),
        'black':  Color(0xFFFFFFFF),
      },
      displayStyle: display.copyWith(fontSize: 28, letterSpacing: -0.02, height: 1.1, color: const Color(0xFF14151A)),
      h1Style:      display.copyWith(fontSize: 28, letterSpacing: -0.02, height: 1.1, color: const Color(0xFF14151A)),
      h2Style:      GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.015, height: 1.15, color: const Color(0xFF14151A)),
      labelStyle:   GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.06, color: const Color(0xFF878C9C)),
      miniStyle:    GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.06, color: const Color(0xFF878C9C)),
      numStyle:     display.copyWith(fontSize: 22, letterSpacing: -0.01, color: const Color(0xFF14151A)),
      bodyStyle:    body.copyWith(fontSize: 14, height: 1.5, color: const Color(0xFF3D4150)),
      isSport:   false,
      cardRadius: 20,
      badgeRadius: 999,
    );
  }

  Color giColor(String type) {
    switch (type.toLowerCase()) {
      case 'nogi':
      case 'no-gi':
        return noGi;
      case 'both':
        return both;
      default:
        return gi;
    }
  }

  Color expColor(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
      case 'beg':
        return beginner;
      case 'intermediate':
      case 'int':
        return intermediate;
      case 'advanced':
      case 'adv':
        return advanced;
      default:
        return allLevels;
    }
  }

  @override
  AppTokens copyWith({
    Color? bg, Color? bg2, Color? surface, Color? surfaceHi,
    Color? border, Color? borderHi, Color? text, Color? body,
    Color? muted, Color? faint, Color? primary, Color? panel, Color? gold,
    Color? red, Color? amber, Color? green,
    Color? gi, Color? noGi, Color? both,
    Color? allLevels, Color? beginner, Color? intermediate, Color? advanced,
    Map<String, Color>? beltBg, Map<String, Color>? beltFg,
    TextStyle? displayStyle, TextStyle? h1Style, TextStyle? h2Style,
    TextStyle? labelStyle, TextStyle? miniStyle, TextStyle? numStyle,
    TextStyle? bodyStyle, bool? isSport, double? cardRadius, double? badgeRadius,
  }) {
    return AppTokens(
      bg: bg ?? this.bg, bg2: bg2 ?? this.bg2,
      surface: surface ?? this.surface, surfaceHi: surfaceHi ?? this.surfaceHi,
      border: border ?? this.border, borderHi: borderHi ?? this.borderHi,
      text: text ?? this.text, body: body ?? this.body,
      muted: muted ?? this.muted, faint: faint ?? this.faint,
      primary: primary ?? this.primary,
      panel: panel ?? this.panel,
      gold: gold ?? this.gold,
      red: red ?? this.red, amber: amber ?? this.amber, green: green ?? this.green,
      gi: gi ?? this.gi, noGi: noGi ?? this.noGi, both: both ?? this.both,
      allLevels: allLevels ?? this.allLevels, beginner: beginner ?? this.beginner,
      intermediate: intermediate ?? this.intermediate, advanced: advanced ?? this.advanced,
      beltBg: beltBg ?? this.beltBg, beltFg: beltFg ?? this.beltFg,
      displayStyle: displayStyle ?? this.displayStyle, h1Style: h1Style ?? this.h1Style,
      h2Style: h2Style ?? this.h2Style, labelStyle: labelStyle ?? this.labelStyle,
      miniStyle: miniStyle ?? this.miniStyle, numStyle: numStyle ?? this.numStyle,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      isSport: isSport ?? this.isSport,
      cardRadius: cardRadius ?? this.cardRadius, badgeRadius: badgeRadius ?? this.badgeRadius,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return copyWith(
      bg: Color.lerp(bg, other.bg, t),
      surface: Color.lerp(surface, other.surface, t),
      text: Color.lerp(text, other.text, t),
    );
  }
}

# BJJ Open Mat UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle all 8 app screens to match two design directions — Sports Ticker (dark navy, Barlow Condensed, ESPN scoreboard) and Light Glass (frosted glass, pastel gradient) — switchable at runtime.

**Architecture:** `AppTokens extends ThemeExtension<AppTokens>` carries per-theme design tokens into every widget via `Theme.of(context).extension<AppTokens>()!`. A `ThemeVariant` Riverpod `NotifierProvider` drives `MaterialApp`'s `theme`/`darkTheme`. All new shared widgets read from `AppTokens` so they automatically adapt to the active theme.

**Tech Stack:** Flutter 3, Riverpod 3 (NotifierProvider), Go Router 17, google_fonts (Barlow + Barlow Condensed), lucide_icons, google_maps_flutter.

**Design reference files:** `docs/design/tokens.jsx` (Light Glass tokens), `docs/design/tokens-sport.jsx` (Sport tokens), `docs/design/screens.jsx` (Light Glass screens), `docs/design/screens-sport.jsx` (Sport screens).

---

## Task 1: Add google_fonts and lucide_icons packages

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add packages to pubspec.yaml**

In `pubspec.yaml` under `dependencies:`, add:
```yaml
  google_fonts: ^6.1.0
  lucide_icons: ^0.0.2
```

- [ ] **Step 2: Get packages**

```bash
flutter pub get
```

Expected: resolves without errors, `pubspec.lock` updated.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add google_fonts and lucide_icons"
```

---

## Task 2: AppTokens ThemeExtension

**Files:**
- Create: `lib/core/design/tokens.dart`

This file defines `AppTokens extends ThemeExtension<AppTokens>` plus two factory constructors `AppTokens.sport()` and `AppTokens.glass()`. Every widget reads tokens from here via `Theme.of(context).extension<AppTokens>()!`.

- [ ] **Step 1: Create lib/core/design/tokens.dart**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTokens extends ThemeExtension<AppTokens> {
  // Surfaces
  final Color bg;
  final Color bg2;
  final Color surface;
  final Color surfaceHi;
  final Color border;
  final Color borderHi;

  // Text
  final Color text;
  final Color body;
  final Color muted;
  final Color faint;

  // Brand / status
  final Color red;
  final Color amber;
  final Color green;

  // Gi types
  final Color gi;
  final Color noGi;
  final Color both;

  // Experience
  final Color allLevels;
  final Color beginner;
  final Color intermediate;
  final Color advanced;

  // Belt colors
  final Map<String, Color> beltBg;
  final Map<String, Color> beltFg;

  // Typography
  final TextStyle displayStyle;
  final TextStyle h1Style;
  final TextStyle h2Style;
  final TextStyle labelStyle;
  final TextStyle miniStyle;
  final TextStyle numStyle;
  final TextStyle bodyStyle;

  // Flags
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
        'blue': Colors.white,
        'purple': Colors.white,
        'brown': Colors.white,
        'black': Colors.white,
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
    final display = GoogleFonts.barlow(fontWeight: FontWeight.w700);
    return AppTokens(
      bg: const Color(0xFFF4F1EC),
      bg2: const Color(0xFFF8F5EF),
      surface: const Color(0x8CFFFFFF),
      surfaceHi: const Color(0xC7FFFFFF),
      border: const Color(0xA6FFFFFF),
      borderHi: const Color(0xD9FFFFFF),
      text: const Color(0xFF0F1430),
      body: const Color(0xBF0F1430),
      muted: const Color(0x8C0F1430),
      faint: const Color(0x590F1430),
      red: const Color(0xFFE94560),
      amber: const Color(0xFFF7B731),
      green: const Color(0xFF16C79A),
      gi: const Color(0xFF2196F3),
      noGi: const Color(0xFFFF9800),
      both: const Color(0xFF9C27B0),
      allLevels: const Color(0xFF16C79A),
      beginner: const Color(0xFF3DDC84),
      intermediate: const Color(0xFFFF9800),
      advanced: const Color(0xFFE94560),
      beltBg: const {
        'white': Color(0xFFF5F5F5),
        'blue': Color(0xFF1E5BC9),
        'purple': Color(0xFF6A2A9A),
        'brown': Color(0xFF6B3A1A),
        'black': Color(0xFF0A0A0A),
      },
      beltFg: const {
        'white': Color(0xFF1A1A2E),
        'blue': Colors.white,
        'purple': Colors.white,
        'brown': Colors.white,
        'black': Colors.white,
      },
      displayStyle: display.copyWith(fontSize: 22, color: const Color(0xFF0F1430)),
      h1Style: display.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF0F1430),
      ),
      h2Style: display.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF0F1430),
      ),
      labelStyle: GoogleFonts.barlow(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.08,
        color: const Color(0x8C0F1430),
      ),
      miniStyle: GoogleFonts.barlow(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: const Color(0x8C0F1430),
      ),
      numStyle: GoogleFonts.barlow(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF0F1430),
      ),
      bodyStyle: GoogleFonts.barlow(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        color: const Color(0xBF0F1430),
      ),
      isSport: false,
      cardRadius: 16,
      badgeRadius: 6,
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
    Color? muted, Color? faint, Color? red, Color? amber, Color? green,
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/design/tokens.dart
git commit -m "feat: add AppTokens ThemeExtension with sport and glass token sets"
```

---

## Task 3: AppTheme + ThemeNotifier + wire main.dart

**Files:**
- Create: `lib/core/design/app_theme.dart`
- Create: `lib/core/design/theme_provider.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Create lib/core/design/app_theme.dart**

```dart
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
```

- [ ] **Step 2: Create lib/core/design/theme_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ThemeVariant { sport, glass }

class ThemeNotifier extends Notifier<ThemeVariant> {
  @override
  ThemeVariant build() => ThemeVariant.sport;

  void toggle() {
    state = state == ThemeVariant.sport ? ThemeVariant.glass : ThemeVariant.sport;
  }

  void set(ThemeVariant variant) {
    state = variant;
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeVariant>(ThemeNotifier.new);
```

- [ ] **Step 3: Update lib/main.dart to wire the themes**

Replace the `MaterialApp.router(...)` call in `main.dart` so it reads from `themeProvider`. The file currently has:
```dart
return MaterialApp.router(
  routerConfig: router,
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  ...
);
```

Change to:
```dart
import '../core/design/app_theme.dart';
import '../core/design/theme_provider.dart';

// inside the build method, get the variant:
final variant = ref.watch(themeProvider);

return MaterialApp.router(
  routerConfig: router,
  theme: variant == ThemeVariant.sport ? AppTheme.sport() : AppTheme.glass(),
  themeMode: ThemeMode.light,
  ...
);
```

The widget must extend `ConsumerWidget` or use `Consumer`. If `main.dart` already uses a `ConsumerWidget` for the app root, just add `ref.watch(themeProvider)` inside `build`.

- [ ] **Step 4: Remove old AppTheme.light() / AppTheme.dark() references from lib/app/theme.dart**

Keep `StitchTokens` and `BeltColors` (some screens may still reference them). Just leave the file as-is for now.

- [ ] **Step 5: Verify app builds**

```bash
flutter build web --no-tree-shake-icons 2>&1 | tail -20
```

Expected: no errors (warnings ok).

- [ ] **Step 6: Commit**

```bash
git add lib/core/design/ lib/main.dart
git commit -m "feat: add AppTheme sport/glass + ThemeNotifier + wire main.dart"
```

---

## Task 4: GiBadge, ExpBadge, BeltBadge shared widgets

**Files:**
- Create: `lib/shared/widgets/gi_badge.dart`
- Create: `lib/shared/widgets/exp_badge.dart`
- Create: `lib/shared/widgets/belt_badge.dart`

These widgets read `AppTokens` and render correctly in both Sport and Glass themes.

- [ ] **Step 1: Create lib/shared/widgets/gi_badge.dart**

```dart
import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

class GiBadge extends StatelessWidget {
  final String type; // 'gi', 'nogi', 'both'
  final bool small;

  const GiBadge({super.key, required this.type, this.small = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final color = t.giColor(type);
    final label = switch (type.toLowerCase()) {
      'nogi' || 'no-gi' => 'No-Gi',
      'both' => 'Gi+No-Gi',
      _ => 'Gi',
    };
    final fontSize = small ? 9.0 : 11.0;
    final padding = small
        ? const EdgeInsets.fromLTRB(5, 3, 7, 3)
        : const EdgeInsets.fromLTRB(6, 4, 9, 4);

    if (t.isSport) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color.withOpacity(0.11),
          border: Border(left: BorderSide(color: color, width: 2)),
        ),
        child: Text(
          label.toUpperCase(),
          style: t.miniStyle.copyWith(color: color, fontSize: fontSize),
        ),
      );
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(t.badgeRadius),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: t.miniStyle.copyWith(color: color, fontSize: fontSize),
      ),
    );
  }
}
```

- [ ] **Step 2: Create lib/shared/widgets/exp_badge.dart**

```dart
import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

class ExpBadge extends StatelessWidget {
  final String level; // 'all', 'beg', 'int', 'adv'
  final bool small;

  const ExpBadge({super.key, required this.level, this.small = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final color = t.expColor(level);
    final label = switch (level.toLowerCase()) {
      'beg' || 'beginner' => t.isSport ? 'Begin' : 'Beginner',
      'int' || 'intermediate' => t.isSport ? 'Inter' : 'Intermediate',
      'adv' || 'advanced' => t.isSport ? 'Adv' : 'Advanced',
      _ => t.isSport ? 'All Lv' : 'All Levels',
    };
    final fontSize = small ? 9.0 : 11.0;
    final padding = small
        ? const EdgeInsets.symmetric(horizontal: 7, vertical: 3)
        : const EdgeInsets.symmetric(horizontal: 9, vertical: 4);

    if (t.isSport) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color.withOpacity(0.11),
          border: Border(left: BorderSide(color: color, width: 2)),
        ),
        child: Text(
          label.toUpperCase(),
          style: t.miniStyle.copyWith(color: color, fontSize: fontSize),
        ),
      );
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(t.badgeRadius),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: t.miniStyle.copyWith(color: color, fontSize: fontSize),
      ),
    );
  }
}
```

- [ ] **Step 3: Create lib/shared/widgets/belt_badge.dart**

```dart
import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

class BeltBadge extends StatelessWidget {
  final String belt; // 'white','blue','purple','brown','black'
  final int stripes;
  final bool small;

  const BeltBadge({super.key, required this.belt, this.stripes = 0, this.small = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final bg = t.beltBg[belt] ?? t.beltBg['white']!;
    final fg = t.beltFg[belt] ?? t.beltFg['white']!;
    final height = small ? 14.0 : 18.0;
    final fontSize = small ? 8.0 : 10.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: bg,
          alignment: Alignment.center,
          child: Text(
            belt.toUpperCase(),
            style: t.miniStyle.copyWith(color: fg, fontSize: fontSize),
          ),
        ),
        Container(
          height: height,
          width: 14,
          color: Colors.black,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(stripes, (_) =>
              Container(width: 2, height: height - 4, color: Colors.white, margin: const EdgeInsets.symmetric(horizontal: 0.5)),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/shared/widgets/gi_badge.dart lib/shared/widgets/exp_badge.dart lib/shared/widgets/belt_badge.dart
git commit -m "feat: add GiBadge, ExpBadge, BeltBadge themed widgets"
```

---

## Task 5: SessionRow widget (both themes)

**Files:**
- Create: `lib/shared/widgets/session_row.dart`

Renders a session in Sport theme as a dense scoreboard row (3px left accent, grid layout) and in Glass theme as a frosted card.

- [ ] **Step 1: Create lib/shared/widgets/session_row.dart**

```dart
import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';
import 'gi_badge.dart';
import 'exp_badge.dart';
import 'live_dot.dart';

class SessionRowData {
  final String gymName;
  final String giType;    // 'gi', 'nogi', 'both'
  final String expLevel;  // 'all', 'beg', 'int', 'adv'
  final String time;      // '7:00 PM'
  final String day;       // 'Mon'
  final String distance;  // '0.8 mi'
  final double fee;
  final bool isLive;

  const SessionRowData({
    required this.gymName,
    required this.giType,
    required this.expLevel,
    required this.time,
    required this.day,
    required this.distance,
    required this.fee,
    this.isLive = false,
  });
}

class SessionRow extends StatelessWidget {
  final SessionRowData session;
  final VoidCallback? onTap;

  const SessionRow({super.key, required this.session, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return t.isSport ? _SportRow(session: session, onTap: onTap, t: t)
                     : _GlassCard(session: session, onTap: onTap, t: t);
  }
}

class _SportRow extends StatelessWidget {
  final SessionRowData session;
  final VoidCallback? onTap;
  final AppTokens t;

  const _SportRow({required this.session, required this.onTap, required this.t});

  @override
  Widget build(BuildContext context) {
    final accent = t.giColor(session.giType);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Time column
            SizedBox(
              width: 54,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.day, style: t.miniStyle.copyWith(fontSize: 9)),
                  const SizedBox(height: 2),
                  Text(session.time.split(' ').first,
                      style: t.numStyle.copyWith(fontSize: 16)),
                ],
              ),
            ),
            Container(width: 1, height: 40, color: t.border, margin: const EdgeInsets.only(right: 10)),
            // Main column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (session.isLive) ...[const LiveDot(), const SizedBox(width: 6)],
                    Text(session.distance, style: t.miniStyle.copyWith(fontSize: 9)),
                  ]),
                  const SizedBox(height: 2),
                  Text(session.gymName, style: t.h2Style.copyWith(fontSize: 14, letterSpacing: 0.03)),
                  const SizedBox(height: 6),
                  Row(children: [
                    GiBadge(type: session.giType, small: true),
                    const SizedBox(width: 4),
                    ExpBadge(level: session.expLevel, small: true),
                  ]),
                ],
              ),
            ),
            // Fee column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Mat Fee', style: t.miniStyle.copyWith(fontSize: 9)),
                const SizedBox(height: 2),
                Text(
                  session.fee == 0 ? 'FREE' : '\$${session.fee.toStringAsFixed(0)}',
                  style: t.numStyle.copyWith(
                    fontSize: 22,
                    color: session.fee == 0 ? t.green : t.text,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final SessionRowData session;
  final VoidCallback? onTap;
  final AppTokens t;

  const _GlassCard({required this.session, required this.onTap, required this.t});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: t.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: t.giColor(session.giType).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(session.time.split(':').first,
                    style: t.numStyle.copyWith(fontSize: 18, color: t.giColor(session.giType))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.gymName, style: t.h2Style.copyWith(fontSize: 15)),
                  const SizedBox(height: 6),
                  Row(children: [
                    GiBadge(type: session.giType, small: true),
                    const SizedBox(width: 4),
                    ExpBadge(level: session.expLevel, small: true),
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(session.distance, style: t.miniStyle),
                const SizedBox(height: 4),
                Text(
                  session.fee == 0 ? 'Free' : '\$${session.fee.toStringAsFixed(0)}',
                  style: t.numStyle.copyWith(
                    fontSize: 18,
                    color: session.fee == 0 ? t.green : t.text,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/shared/widgets/session_row.dart
git commit -m "feat: add SessionRow widget (sport + glass variants)"
```

---

## Task 6: StatBar, ScoreCell, LiveDot, TickerStrip

**Files:**
- Create: `lib/shared/widgets/live_dot.dart`
- Create: `lib/shared/widgets/stat_bar.dart`
- Create: `lib/shared/widgets/score_cell.dart`
- Create: `lib/shared/widgets/ticker_strip.dart`

- [ ] **Step 1: Create lib/shared/widgets/live_dot.dart**

```dart
import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

class LiveDot extends StatefulWidget {
  final Color? color;
  final String label;
  final double size;

  const LiveDot({super.key, this.color, this.label = 'Live', this.size = 7});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _anim = Tween<double>(begin: 1.0, end: 0.4).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final c = widget.color ?? t.green;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Opacity(
          opacity: _anim.value,
          child: Container(
            width: widget.size, height: widget.size,
            decoration: BoxDecoration(
              color: c, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: c.withOpacity(0.6), blurRadius: 6)],
            ),
          ),
        ),
      ),
      const SizedBox(width: 5),
      Text(widget.label,
          style: Theme.of(context).extension<AppTokens>()!.miniStyle.copyWith(color: c, fontSize: 9)),
    ]);
  }
}
```

- [ ] **Step 2: Create lib/shared/widgets/stat_bar.dart**

```dart
import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

class StatBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color? color;
  final String? suffix;

  const StatBar({
    super.key,
    required this.label,
    required this.value,
    this.max = 5,
    this.color,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final c = color ?? t.red;
    final pct = (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: t.miniStyle.copyWith(fontSize: 10))),
          Text(value.toStringAsFixed(1),
              style: t.numStyle.copyWith(fontSize: 14)),
          if (suffix != null)
            Text(' $suffix', style: t.miniStyle),
        ]),
        const SizedBox(height: 5),
        ClipRect(
          child: SizedBox(
            height: 5,
            child: Stack(children: [
              Container(color: t.isSport ? const Color(0xFF080F26) : Colors.black12),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(color: c),
              ),
              // tick marks
              Row(children: List.generate(max.toInt() - 1, (i) =>
                Expanded(child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(width: 1, height: 5, color: t.bg),
                )),
              )),
            ]),
          ),
        ),
      ]),
    );
  }
}
```

- [ ] **Step 3: Create lib/shared/widgets/score_cell.dart**

```dart
import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

class ScoreCell extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  final String? sub;
  final Color? valueColor;
  final Color? accent;

  const ScoreCell({
    super.key,
    required this.label,
    required this.value,
    this.suffix,
    this.sub,
    this.valueColor,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          if (accent != null) ...[
            Container(width: 6, height: 6, color: accent),
            const SizedBox(width: 4),
          ],
          Text(label, style: t.miniStyle.copyWith(fontSize: 9)),
        ]),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(value, style: t.numStyle.copyWith(fontSize: 26, color: valueColor ?? t.text)),
          if (suffix != null) ...[
            const SizedBox(width: 3),
            Text(suffix!, style: t.numStyle.copyWith(fontSize: 12, color: t.muted)),
          ],
        ]),
        if (sub != null) Text(sub!, style: t.miniStyle.copyWith(color: t.faint, fontSize: 9)),
      ],
    );
  }
}
```

- [ ] **Step 4: Create lib/shared/widgets/ticker_strip.dart**

```dart
import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';
import 'gi_badge.dart';
import 'live_dot.dart';

class TickerItem {
  final String time;
  final String gym;
  final String giType;
  const TickerItem({required this.time, required this.gym, required this.giType});
}

class TickerStrip extends StatelessWidget {
  final List<TickerItem> items;
  const TickerStrip({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          children: items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            return Row(children: [
              const SizedBox(width: 14),
              const LiveDot(size: 6),
              const SizedBox(width: 8),
              Text(item.time, style: t.miniStyle.copyWith(fontSize: 9)),
              const SizedBox(width: 6),
              Text(item.gym, style: t.h2Style.copyWith(fontSize: 12)),
              const SizedBox(width: 6),
              GiBadge(type: item.giType, small: true),
              if (i < items.length - 1) ...[
                const SizedBox(width: 16),
                Text('·', style: TextStyle(color: t.borderHi, fontSize: 14)),
              ],
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/live_dot.dart lib/shared/widgets/stat_bar.dart lib/shared/widgets/score_cell.dart lib/shared/widgets/ticker_strip.dart
git commit -m "feat: add LiveDot, StatBar, ScoreCell, TickerStrip widgets"
```

---

## Task 7: AppBottomNav

**Files:**
- Create: `lib/shared/widgets/app_bottom_nav.dart`

- [ ] **Step 1: Create lib/shared/widgets/app_bottom_nav.dart**

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/design/tokens.dart';

class AppBottomNav extends StatelessWidget {
  final String active; // 'home', 'search', 'schedule', 'profile'
  final void Function(String tab) onTap;

  const AppBottomNav({super.key, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final tabs = [
      (id: 'home',     icon: LucideIcons.home,     label: t.isSport ? 'Feed'  : 'Discover'),
      (id: 'search',   icon: LucideIcons.search,   label: t.isSport ? 'Find'  : 'Search'),
      (id: 'schedule', icon: LucideIcons.calendar, label: t.isSport ? 'Sched' : 'Training'),
      (id: 'profile',  icon: LucideIcons.user,     label: t.isSport ? 'Me'    : 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: t.bg2,
        border: Border(top: BorderSide(color: t.borderHi, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: tabs.map((tab) {
            final on = tab.id == active;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(tab.id),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: on && t.isSport ? t.surface : Colors.transparent,
                    border: on && t.isSport
                        ? Border(top: BorderSide(color: t.amber, width: 3))
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!t.isSport && on)
                        Container(
                          width: 4, height: 4,
                          decoration: BoxDecoration(color: t.red, shape: BoxShape.circle),
                          margin: const EdgeInsets.only(bottom: 2),
                        ),
                      Icon(tab.icon,
                          size: 20,
                          color: on ? t.text : t.muted),
                      const SizedBox(height: 3),
                      Text(
                        tab.label,
                        style: t.miniStyle.copyWith(
                          color: on ? t.text : t.muted,
                          fontSize: t.isSport ? 10 : 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/shared/widgets/app_bottom_nav.dart
git commit -m "feat: add themed AppBottomNav widget"
```

---

## Task 8: HomeScreen (Discover)

**Files:**
- Modify: `lib/features/discover/screens/discover_screen.dart`

**Design reference:** `docs/design/screens-sport.jsx` → `SpHome` component; `docs/design/screens.jsx` → `ScreenHome` component.

**Sport layout:**
1. Masthead: left red bar + "Open Mat" condensed title + date + bell/search icons
2. Ticker strip (TickerStrip widget)
3. Quick stats strip: 4-column grid with OPEN NOW / TONIGHT / THIS WK / NEAREST counts
4. Dark map (Google Maps in night mode) with rectangular colored pin labels
5. Section header "Live Feed" with SpSectionHead pattern
6. Session rows list (SessionRow widgets)

**Glass layout:**
1. Map fills top 45% with floating pill chips for filter (Today/Week)
2. Draggable bottom sheet with session cards list
3. Search bar at top of map overlay

- [ ] **Step 1: Rewrite discover_screen.dart**

Read the existing file at `lib/features/discover/screens/discover_screen.dart` first, then replace its content with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/session_row.dart';
import '../../../shared/widgets/ticker_strip.dart';
import '../../../shared/widgets/score_cell.dart';
import '../../../shared/widgets/app_bottom_nav.dart';

// Stub data — replace with real providers
final _stubSessions = [
  SessionRowData(gymName: 'Atos HQ', giType: 'gi', expLevel: 'all', time: '7:00 PM', day: 'Mon', distance: '1.2 mi', fee: 0, isLive: true),
  SessionRowData(gymName: 'Renzo Westwood', giType: 'nogi', expLevel: 'int', time: '8:00 PM', day: 'Mon', distance: '2.4 mi', fee: 15),
  SessionRowData(gymName: '10th Planet Rosemead', giType: 'both', expLevel: 'adv', time: '8:30 PM', day: 'Mon', distance: '3.1 mi', fee: 20),
  SessionRowData(gymName: 'Gracie Barra Pasadena', giType: 'gi', expLevel: 'beg', time: '9:00 AM', day: 'Tue', distance: '4.5 mi', fee: 0),
  SessionRowData(gymName: 'CKM Jiu-Jitsu', giType: 'nogi', expLevel: 'all', time: '7:30 PM', day: 'Tue', distance: '5.0 mi', fee: 10),
];

final _tickerItems = [
  TickerItem(time: '7:00 PM', gym: 'Atos HQ', giType: 'gi'),
  TickerItem(time: '8:00 PM', gym: 'Renzo Westwood', giType: 'nogi'),
  TickerItem(time: '8:30 PM', gym: '10P Rosemead', giType: 'both'),
];

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String _filter = 'today';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return t.isSport ? _buildSport(t) : _buildGlass(t);
  }

  Widget _buildSport(AppTokens t) {
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          // Masthead
          Container(
            color: t.bg2,
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Row(children: [
              Container(width: 4, height: 22, color: t.red),
              const SizedBox(width: 8),
              Text('Open Mat', style: t.displayStyle.copyWith(fontSize: 22)),
              const SizedBox(width: 8),
              Text('LA / Mon Jun 2', style: t.miniStyle),
              const Spacer(),
              Icon(LucideIcons.bell, size: 18, color: t.muted),
              const SizedBox(width: 12),
              Icon(LucideIcons.search, size: 18, color: t.muted),
            ]),
          ),
          // Ticker
          TickerStrip(items: _tickerItems),
          // Quick stats strip
          Container(
            color: const Color(0xFF080F26),
            child: Row(children: [
              _StatCell(label: 'Open Now', value: '3', color: t.green, t: t),
              _StatCell(label: 'Tonight', value: '12', color: t.amber, t: t),
              _StatCell(label: 'This Wk', value: '47', color: t.text, t: t),
              _StatCell(label: 'Nearest', value: '1.2mi', color: t.gi, t: t),
            ]),
          ),
          // Map placeholder
          Container(
            height: 200,
            color: const Color(0xFF080F26),
            child: Stack(children: [
              // Grid lines
              CustomPaint(painter: _GridPainter(t), size: Size.infinite),
              // Pins
              ...[
                (x: 0.24, y: 0.36, gi: 'gi',   label: 'ATOS'),
                (x: 0.56, y: 0.28, gi: 'both', label: '10P'),
                (x: 0.78, y: 0.52, gi: 'nogi', label: 'RNZ'),
                (x: 0.38, y: 0.70, gi: 'gi',   label: 'GB'),
              ].map((p) => Positioned(
                left: MediaQuery.of(context).size.width * p.x - 20,
                top: 200 * p.y - 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  color: t.giColor(p.gi),
                  child: Text(p.label, style: t.miniStyle.copyWith(color: Colors.white, fontSize: 11)),
                ),
              )),
            ]),
          ),
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Container(width: 4, height: 22, color: t.red, margin: const EdgeInsets.only(right: 10)),
              Text('Live Feed', style: t.h2Style.copyWith(fontSize: 15)),
              const Spacer(),
              Text('All Sessions', style: t.miniStyle),
            ]),
          ),
          // Session list
          Expanded(
            child: ListView.separated(
              itemCount: _stubSessions.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: t.border),
              itemBuilder: (_, i) => SessionRow(session: _stubSessions[i]),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: AppBottomNav(active: 'home', onTap: (_) {}),
    );
  }

  Widget _buildGlass(AppTokens t) {
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(children: [
        // Gradient backdrop
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.64, -0.84),
              radius: 1.0,
              colors: [Color(0x38E94560), Colors.transparent],
            ),
          ),
        ),
        // Map placeholder (top 45%)
        Positioned(
          top: 0, left: 0, right: 0,
          height: MediaQuery.of(context).size.height * 0.45,
          child: Container(
            color: const Color(0xFFDDE8F0),
            child: CustomPaint(painter: _LightMapPainter(), size: Size.infinite),
          ),
        ),
        // Status bar area
        SafeArea(
          child: Column(children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                Text('Open Mat', style: t.h1Style.copyWith(fontSize: 26)),
                const Spacer(),
                Icon(LucideIcons.bell, size: 20, color: t.muted),
                const SizedBox(width: 12),
                Icon(LucideIcons.search, size: 20, color: t.muted),
              ]),
            ),
            const Spacer(),
            // Draggable sheet
            DraggableScrollableSheet(
              initialChildSize: 0.56,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              snap: true,
              builder: (context, ctrl) => Container(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border.all(color: t.border),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24)],
                ),
                child: Column(children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: t.muted.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(children: [
                      _FilterChip(label: 'Today', active: _filter == 'today', onTap: () => setState(() => _filter = 'today'), t: t),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'This Week', active: _filter == 'week', onTap: () => setState(() => _filter = 'week'), t: t),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'Gi', active: false, onTap: () {}, t: t),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'No-Gi', active: false, onTap: () {}, t: t),
                    ]),
                  ),
                  // List
                  Expanded(
                    child: ListView.separated(
                      controller: ctrl,
                      itemCount: _stubSessions.length,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => SessionRow(session: _stubSessions[i]),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ]),
      bottomNavigationBar: AppBottomNav(active: 'home', onTap: (_) {}),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final AppTokens t;
  const _StatCell({required this.label, required this.value, required this.color, required this.t});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(right: BorderSide(color: t.border, width: 1))),
      child: Column(children: [
        Text(value, style: t.numStyle.copyWith(fontSize: 20, color: color)),
        const SizedBox(height: 2),
        Text(label, style: t.miniStyle.copyWith(fontSize: 8)),
      ]),
    ));
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final AppTokens t;
  const _FilterChip({required this.label, required this.active, required this.onTap, required this.t});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? t.red : t.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? t.red : t.border),
        ),
        child: Text(label, style: t.miniStyle.copyWith(color: active ? Colors.white : t.text, fontSize: 12)),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final AppTokens t;
  _GridPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = t.border..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += 40) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    // Roads
    final road = Paint()..color = t.border..strokeWidth = 8;
    canvas.drawLine(const Offset(-20, 70), Offset(size.width + 20, 110), road);
    canvas.drawLine(const Offset(-20, 200), Offset(size.width + 20, 170), road);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _LightMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Light map background roads
    final bg = Paint()..color = const Color(0xFFE8EFF5);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);
    final road = Paint()..color = Colors.white..strokeWidth = 8;
    canvas.drawLine(Offset(-20, size.height * 0.3), Offset(size.width + 20, size.height * 0.45), road);
    canvas.drawLine(Offset(-20, size.height * 0.7), Offset(size.width + 20, size.height * 0.6), road);
    canvas.drawLine(Offset(size.width * 0.3, -20), Offset(size.width * 0.28, size.height + 20), road);
    canvas.drawLine(Offset(size.width * 0.65, -20), Offset(size.width * 0.75, size.height + 20), road);
  }

  @override
  bool shouldRepaint(_) => false;
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter build web --no-tree-shake-icons 2>&1 | grep -i error | head -20
```

Fix any import errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/discover/screens/discover_screen.dart
git commit -m "feat: restyle HomeScreen to match Sport Ticker + Light Glass designs"
```

---

## Task 9: SearchScreen

**Files:**
- Modify: `lib/features/search/screens/search_screen.dart`

**Design reference:** `docs/design/screens-sport.jsx` → `SpSearch`; `docs/design/screens.jsx` → `ScreenSearch`.

**Sport layout:**
- Search bar with dark background, sharp border
- Filter tabs: Gi | No-Gi | Both | All (3px top border on active)
- Distance slider cell (label + value on right)
- Session rows list

**Glass layout:**
- Frosted search bar with glass pill styling
- Horizontal scrolling filter chips (same as Home)
- Session cards

- [ ] **Step 1: Read current search_screen.dart, then replace with redesigned version**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/session_row.dart';
import '../../../shared/widgets/app_bottom_nav.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _giFilter = 'all'; // 'gi', 'nogi', 'both', 'all'
  double _distance = 10.0;
  final _searchCtrl = TextEditingController();

  final _sessions = [
    SessionRowData(gymName: 'Atos HQ', giType: 'gi', expLevel: 'all', time: '7:00 PM', day: 'Mon', distance: '1.2 mi', fee: 0),
    SessionRowData(gymName: 'Renzo Westwood', giType: 'nogi', expLevel: 'int', time: '8:00 PM', day: 'Mon', distance: '2.4 mi', fee: 15),
    SessionRowData(gymName: '10th Planet Rosemead', giType: 'both', expLevel: 'adv', time: '8:30 PM', day: 'Mon', distance: '3.1 mi', fee: 20),
    SessionRowData(gymName: 'Gracie Barra Pasadena', giType: 'gi', expLevel: 'beg', time: '9:00 AM', day: 'Tue', distance: '4.5 mi', fee: 0),
    SessionRowData(gymName: 'CKM Jiu-Jitsu', giType: 'nogi', expLevel: 'all', time: '7:30 PM', day: 'Tue', distance: '5.0 mi', fee: 10),
    SessionRowData(gymName: 'Alliance Atlanta', giType: 'gi', expLevel: 'int', time: '6:00 PM', day: 'Wed', distance: '6.2 mi', fee: 0),
    SessionRowData(gymName: 'B-Team Jiu-Jitsu', giType: 'both', expLevel: 'adv', time: '9:00 PM', day: 'Wed', distance: '7.1 mi', fee: 25),
    SessionRowData(gymName: 'Marcelo Garcia NY', giType: 'both', expLevel: 'all', time: '7:00 PM', day: 'Thu', distance: '8.0 mi', fee: 30),
  ];

  List<SessionRowData> get _filtered {
    return _sessions.where((s) {
      if (_giFilter != 'all' && s.giType != _giFilter) return false;
      final dist = double.tryParse(s.distance.split(' ').first) ?? 0;
      if (dist > _distance) return false;
      if (_searchCtrl.text.isNotEmpty &&
          !s.gymName.toLowerCase().contains(_searchCtrl.text.toLowerCase())) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return t.isSport ? _buildSport(t) : _buildGlass(t);
  }

  Widget _buildSport(AppTokens t) {
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Container(
            color: t.bg2,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 4, height: 22, color: t.red),
                const SizedBox(width: 8),
                Text('Find Sessions', style: t.h1Style.copyWith(fontSize: 20)),
              ]),
              const SizedBox(height: 10),
              // Search bar
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border.all(color: t.border),
                ),
                child: Row(children: [
                  const SizedBox(width: 12),
                  Icon(LucideIcons.search, size: 16, color: t.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: t.bodyStyle,
                      decoration: InputDecoration(
                        hintText: 'Gym, location…',
                        hintStyle: t.miniStyle.copyWith(fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              // Gi filter tabs
              Row(children: ['All', 'Gi', 'No-Gi', 'Both'].map((label) {
                final id = label.toLowerCase().replaceAll('-', '');
                final active = _giFilter == id || (_giFilter == 'all' && label == 'All');
                return Expanded(child: GestureDetector(
                  onTap: () => setState(() => _giFilter = id == 'all' ? 'all' : id == 'nogi' ? 'nogi' : id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? t.surfaceHi : Colors.transparent,
                      border: active ? Border(top: BorderSide(color: t.amber, width: 3)) : null,
                    ),
                    child: Text(
                      label.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: t.miniStyle.copyWith(color: active ? t.text : t.muted, fontSize: 11),
                    ),
                  ),
                ));
              }).toList()),
            ]),
          ),
          // Distance
          Container(
            color: t.surface,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(children: [
              Text('Distance', style: t.miniStyle.copyWith(fontSize: 10)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: t.red,
                    inactiveTrackColor: t.border,
                    thumbColor: t.red,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: _distance,
                    min: 1,
                    max: 50,
                    onChanged: (v) => setState(() => _distance = v),
                  ),
                ),
              ),
              Text('${_distance.toStringAsFixed(0)} mi',
                  style: t.numStyle.copyWith(fontSize: 14)),
            ]),
          ),
          Divider(height: 1, color: t.border),
          // Results count
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(children: [
              Container(width: 4, height: 16, color: t.red, margin: const EdgeInsets.only(right: 8)),
              Text('Results', style: t.h2Style.copyWith(fontSize: 13)),
              const Spacer(),
              Text('${_filtered.length} sessions', style: t.miniStyle),
            ]),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: t.border),
              itemBuilder: (_, i) => SessionRow(session: _filtered[i]),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: AppBottomNav(active: 'search', onTap: (_) {}),
    );
  }

  Widget _buildGlass(AppTokens t) {
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(children: [
              Text('Search', style: t.h1Style),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: t.surfaceHi,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  Icon(LucideIcons.search, size: 16, color: t.muted),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search gyms, neighborhoods…',
                      hintStyle: t.miniStyle.copyWith(fontSize: 13),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  )),
                ]),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: ['All', 'Gi', 'No-Gi', 'Both', 'Free', 'Nearby'].map((label) {
                  final active = label == 'All' && _giFilter == 'all';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _giFilter = label == 'All' ? 'all' : label.toLowerCase().replaceAll('-', '')),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? t.red : t.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: active ? t.red : t.border),
                        ),
                        child: Text(label, style: t.miniStyle.copyWith(color: active ? Colors.white : t.text, fontSize: 12)),
                      ),
                    ),
                  );
                }).toList()),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => SessionRow(session: _filtered[i]),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: AppBottomNav(active: 'search', onTap: (_) {}),
    );
  }
}
```

- [ ] **Step 2: Verify compiles, commit**

```bash
flutter build web --no-tree-shake-icons 2>&1 | grep -i error | head -20
git add lib/features/search/screens/search_screen.dart
git commit -m "feat: restyle SearchScreen to match Sport/Glass designs"
```

---

## Task 10: OpenMatDetailScreen

**Files:**
- Modify: `lib/features/open_mats/screens/open_mat_detail_screen.dart`

**Design reference:** `docs/design/screens-sport.jsx` → `SpDetail`; `docs/design/screens.jsx` → `ScreenDetail`.

**Sport layout:**
1. Top bar with back + gym name + share
2. 4-cell scoreboard strip (DATE / START / END / FEE) using `ScoreCell`
3. Section "STAT SHEET" with 4 `StatBar` gauges: Experience Mix, Avg Attendance, Instructor Rating, Mat Quality
4. Description block
5. CTA button "Check In — Free" at bottom

**Glass layout:**
1. Hero image area (gradient overlay) with gym name + badges
2. Session info cards (date, time, fee)
3. Description
4. Instructor chip
5. Check-in button

- [ ] **Step 1: Read existing open_mat_detail_screen.dart, then replace with redesigned version**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/gi_badge.dart';
import '../../../shared/widgets/exp_badge.dart';
import '../../../shared/widgets/belt_badge.dart';
import '../../../shared/widgets/stat_bar.dart';
import '../../../shared/widgets/score_cell.dart';

class OpenMatDetailScreen extends ConsumerWidget {
  final String? sessionId;
  const OpenMatDetailScreen({super.key, this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return t.isSport ? _SportDetail(t: t) : _GlassDetail(t: t);
  }
}

class _SportDetail extends StatelessWidget {
  final AppTokens t;
  const _SportDetail({required this.t});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          // Top bar
          Container(
            color: t.bg2,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(LucideIcons.arrowLeft, size: 20, color: t.text),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ATOS HQ', style: t.h1Style.copyWith(fontSize: 24)),
                  Text('Los Angeles, CA', style: t.miniStyle),
                ],
              )),
              Icon(LucideIcons.share2, size: 18, color: t.muted),
            ]),
          ),
          Divider(height: 1, color: t.border),
          // Gi + Exp badges row
          Container(
            color: t.surface,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(children: [
              const GiBadge(type: 'gi'),
              const SizedBox(width: 8),
              const ExpBadge(level: 'all'),
              const Spacer(),
              const BeltBadge(belt: 'blue', stripes: 2),
            ]),
          ),
          Divider(height: 1, color: t.border),
          // 4-cell scoreboard
          Container(
            color: t.surfaceHi,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ScoreCell(label: 'Date', value: 'Jun 2', sub: 'Monday'),
                Container(width: 1, height: 40, color: t.border),
                ScoreCell(label: 'Start', value: '7:00', suffix: 'PM'),
                Container(width: 1, height: 40, color: t.border),
                ScoreCell(label: 'End', value: '9:00', suffix: 'PM'),
                Container(width: 1, height: 40, color: t.border),
                ScoreCell(label: 'Fee', value: 'FREE', valueColor: t.green),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Stat sheet
                Row(children: [
                  Container(width: 4, height: 18, color: t.red, margin: const EdgeInsets.only(right: 8)),
                  Text('Stat Sheet', style: t.h2Style.copyWith(fontSize: 14)),
                ]),
                Divider(color: t.border),
                StatBar(label: 'Experience Mix', value: 4.2, color: t.gi),
                StatBar(label: 'Avg Attendance', value: 3.8, color: t.amber),
                StatBar(label: 'Instructor Rating', value: 4.7, color: t.green),
                StatBar(label: 'Mat Quality', value: 4.5, color: t.noGi),
                const SizedBox(height: 16),
                Row(children: [
                  Container(width: 4, height: 18, color: t.red, margin: const EdgeInsets.only(right: 8)),
                  Text('About', style: t.h2Style.copyWith(fontSize: 14)),
                ]),
                Divider(color: t.border),
                Text(
                  'World-class facility with multiple mat rooms. Open mat runs Saturday & Sunday. All skill levels welcome. Instructors on the mat.',
                  style: t.bodyStyle.copyWith(fontSize: 13),
                ),
              ]),
            ),
          ),
          // CTA
          Container(
            color: t.bg2,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: double.infinity,
                height: 54,
                color: t.green,
                child: Stack(children: [
                  Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.checkCircle, size: 18, color: t.bg),
                    const SizedBox(width: 10),
                    Text('Check In — Free', style: t.h2Style.copyWith(color: t.bg, fontSize: 16)),
                  ])),
                  // Corner ticks
                  Positioned(top: 0, left: 0, child: Container(width: 8, height: 8,
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white30, width: 2), left: BorderSide(color: Colors.white30, width: 2))))),
                  Positioned(bottom: 0, right: 0, child: Container(width: 8, height: 8,
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white30, width: 2), right: BorderSide(color: Colors.white30, width: 2))))),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _GlassDetail extends StatelessWidget {
  final AppTokens t;
  const _GlassDetail({required this.t});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          backgroundColor: t.bg2,
          leading: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(LucideIcons.arrowLeft, color: t.text),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [t.gi.withOpacity(0.6), t.both.withOpacity(0.4)],
                  ),
                ),
              ),
              Positioned(bottom: 16, left: 16, right: 16, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ATOS HQ', style: t.h1Style.copyWith(fontSize: 28, color: Colors.white)),
                  const SizedBox(height: 8),
                  Row(children: const [
                    GiBadge(type: 'gi'),
                    SizedBox(width: 6),
                    ExpBadge(level: 'all'),
                  ]),
                ],
              )),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // Info cards row
            Row(children: [
              _InfoCard(label: 'Date', value: 'Jun 2', icon: LucideIcons.calendar, t: t),
              const SizedBox(width: 10),
              _InfoCard(label: 'Time', value: '7:00 PM', icon: LucideIcons.clock, t: t),
              const SizedBox(width: 10),
              _InfoCard(label: 'Fee', value: 'Free', icon: LucideIcons.dollarSign, t: t, valueColor: t.green),
            ]),
            const SizedBox(height: 20),
            Text('About', style: t.h2Style),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(t.cardRadius),
                border: Border.all(color: t.border),
              ),
              child: Text(
                'World-class facility with multiple mat rooms. Open mat runs Saturday & Sunday. All skill levels welcome.',
                style: t.bodyStyle,
              ),
            ),
            const SizedBox(height: 20),
            Text('Ratings', style: t.h2Style),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(t.cardRadius),
                border: Border.all(color: t.border),
              ),
              child: Column(children: [
                StatBar(label: 'Experience Mix', value: 4.2, color: t.gi),
                StatBar(label: 'Instructor Rating', value: 4.7, color: t.green),
                StatBar(label: 'Mat Quality', value: 4.5, color: t.noGi),
              ]),
            ),
            const SizedBox(height: 80),
          ])),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: t.red,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.cardRadius)),
            ),
            child: Text('Check In', style: t.h2Style.copyWith(color: Colors.white, fontSize: 18)),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final AppTokens t;
  final Color? valueColor;
  const _InfoCard({required this.label, required this.value, required this.icon, required this.t, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.border),
      ),
      child: Column(children: [
        Icon(icon, size: 18, color: t.muted),
        const SizedBox(height: 6),
        Text(value, style: t.numStyle.copyWith(fontSize: 16, color: valueColor ?? t.text)),
        Text(label, style: t.miniStyle),
      ]),
    ));
  }
}
```

- [ ] **Step 2: Verify and commit**

```bash
flutter build web --no-tree-shake-icons 2>&1 | grep -i error | head -20
git add lib/features/open_mats/screens/open_mat_detail_screen.dart
git commit -m "feat: restyle OpenMatDetailScreen to match Sport/Glass designs"
```

---

## Task 11: ReviewSheet

**Files:**
- Modify: `lib/features/checkins/screens/review_screen.dart`

**Design reference:** `docs/design/screens-sport.jsx` → `SpReview`; `docs/design/screens.jsx` → `ScreenReview`.

**Sport layout:** Modal bottom sheet. Section header "Rate Session". 5 StatBar-style row gauges (Instruction Quality, Mat Cleanliness, Skill Variety, Worth Returning, Overall). "Composite Score" ScoreCell. Text input for written review. Submit button.

**Glass layout:** Bottom sheet with frosted glass surface. Star rating rows (5 stars each category). Text field. Submit button.

- [ ] **Step 1: Read existing review_screen.dart, then replace**

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/stat_bar.dart';
import '../../../shared/widgets/score_cell.dart';

class ReviewScreen extends StatefulWidget {
  final String? sessionId;
  const ReviewScreen({super.key, this.sessionId});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final Map<String, double> _ratings = {
    'Instruction Quality': 4.0,
    'Mat Cleanliness': 3.0,
    'Skill Variety': 5.0,
    'Worth Returning': 4.0,
    'Overall': 4.0,
  };
  final _reviewCtrl = TextEditingController();

  double get _composite => _ratings.values.reduce((a, b) => a + b) / _ratings.length;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Container(
            color: t.isSport ? t.bg2 : Colors.transparent,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              if (t.isSport) Container(width: 4, height: 22, color: t.red, margin: const EdgeInsets.only(right: 10)),
              Expanded(child: Text('Rate Session', style: t.h1Style.copyWith(fontSize: 20))),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(LucideIcons.x, size: 20, color: t.muted),
              ),
            ]),
          ),
          if (t.isSport) Divider(height: 1, color: t.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (t.isSport) ...[
                  // Composite score
                  Container(
                    color: t.surface,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(children: [
                      ScoreCell(
                        label: 'Composite Score',
                        value: _composite.toStringAsFixed(1),
                        suffix: '/ 5',
                        valueColor: _composite >= 4 ? t.green : _composite >= 3 ? t.amber : t.red,
                      ),
                    ]),
                  ),
                  // Stat bar ratings
                  ..._ratings.entries.map((e) => Column(children: [
                    Row(children: [
                      Expanded(child: Text(e.key.toUpperCase(), style: t.miniStyle.copyWith(fontSize: 10))),
                    ]),
                    Slider(
                      value: e.value,
                      min: 0, max: 5, divisions: 10,
                      activeColor: _barColor(e.value, t),
                      inactiveColor: t.border,
                      onChanged: (v) => setState(() => _ratings[e.key] = v),
                    ),
                    StatBar(label: e.key, value: e.value, color: _barColor(e.value, t)),
                  ])),
                ] else ...[
                  // Glass star ratings
                  ..._ratings.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(t.cardRadius),
                        border: Border.all(color: t.border),
                      ),
                      child: Row(children: [
                        Expanded(child: Text(e.key, style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600))),
                        Row(children: List.generate(5, (i) => GestureDetector(
                          onTap: () => setState(() => _ratings[e.key] = i + 1.0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(
                              i < e.value ? LucideIcons.star : LucideIcons.star,
                              size: 22,
                              color: i < e.value ? t.amber : t.muted,
                            ),
                          ),
                        ))),
                      ]),
                    ),
                  )),
                ],
                const SizedBox(height: 12),
                // Written review
                Container(
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(t.cardRadius),
                    border: Border.all(color: t.border),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _reviewCtrl,
                    style: t.bodyStyle,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Write a review (optional)…',
                      hintStyle: t.miniStyle.copyWith(fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ]),
            ),
          ),
          // Submit
          Container(
            color: t.isSport ? t.bg2 : Colors.transparent,
            padding: const EdgeInsets.all(16),
            child: t.isSport
                ? GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      color: t.red,
                      child: Center(child: Text('Submit Review', style: t.h2Style.copyWith(color: Colors.white, fontSize: 16))),
                    ),
                  )
                : ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.red,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.cardRadius)),
                    ),
                    child: Text('Submit Review', style: t.h2Style.copyWith(color: Colors.white)),
                  ),
          ),
        ]),
      ),
    );
  }

  Color _barColor(double v, AppTokens t) {
    if (v >= 4) return t.green;
    if (v >= 3) return t.amber;
    return t.red;
  }
}
```

- [ ] **Step 2: Verify and commit**

```bash
git add lib/features/checkins/screens/review_screen.dart
git commit -m "feat: restyle ReviewScreen to match Sport/Glass designs"
```

---

## Task 12: GymDetailScreen

**Files:**
- Modify: `lib/features/gyms/screens/gym_detail_screen.dart`

**Design reference:** `docs/design/screens-sport.jsx` → `SpGym`; `docs/design/screens.jsx` → `ScreenGym`.

**Sport layout:**
1. Top bar with back button + gym name
2. "Player Card" strip: 4 ScoreCells (RATING / REVIEWS / MATS/WK / DIST)
3. Section "Upcoming Mats" — fixture list of SessionRows
4. Section "Stat Sheet" — 4 StatBar gauges
5. Map strip at bottom

**Glass layout:**
1. Hero area with gym name + location + rating pill
2. Glass card with stat pills row (rating, hours, distance)
3. "Upcoming Sessions" list
4. About section

- [ ] **Step 1: Read existing gym_detail_screen.dart, then replace with redesigned version that follows the Sport/Glass pattern. Use ScoreCell, StatBar, SessionRow, GiBadge, AppTokens. Stub session data inline. Structure mirrors OpenMatDetailScreen pattern above.**

Key sections to implement:
- `_SportGymDetail` with bg2 top bar, `Row` of 4 `ScoreCell` widgets in a `surfaceHi` container, section headers with red left bar, `SessionRow` list, `StatBar` gauges.
- `_GlassGymDetail` with CustomScrollApp + hero area + glass card with info + session list.

Follow the same `ConsumerWidget` + `build()` pattern dispatching to `_SportGymDetail` or `_GlassGymDetail` based on `t.isSport`.

- [ ] **Step 2: Verify and commit**

```bash
git add lib/features/gyms/screens/gym_detail_screen.dart
git commit -m "feat: restyle GymDetailScreen to match Sport/Glass designs"
```

---

## Task 13: ProfileScreen

**Files:**
- Modify: `lib/features/profile/screens/profile_screen.dart`

**Design reference:** `docs/design/screens-sport.jsx` → `SpProfile`; `docs/design/screens.jsx` → `ScreenProfile`.

**Sport layout:**
1. "Player Card" hero: jersey number eyebrow (`#0027`), full name, belt badge
2. 4-cell stat grid (MATS / HOURS / GYMS / REVIEWS) using ScoreCell
3. Belt progression bar: colored blocks for each rank, current highlighted
4. Section "Recent Sessions" — SessionRow list
5. Section "My Gyms" — gym rows

**Glass layout:**
1. Gradient avatar card with initials, name, belt badge, stat row
2. "My Sessions" card list
3. "Favorite Gyms" card list
4. Settings list (theme toggle, notifications, account, sign out)

**Important:** The settings list must include a **theme toggle** row that calls `ref.read(themeProvider.notifier).toggle()`.

- [ ] **Step 1: Read existing profile_screen.dart, then replace with redesigned version**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/theme_provider.dart';
import '../../../shared/widgets/belt_badge.dart';
import '../../../shared/widgets/score_cell.dart';
import '../../../shared/widgets/session_row.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
```

Implement `ProfileScreen extends ConsumerWidget`. Sport variant shows Player Card hero + stat grid + belt progression bar + session rows. Glass variant shows avatar card + session list + settings list with theme toggle.

Belt progression bar (sport): A `Row` of 5 colored blocks (white/blue/purple/brown/black) with the current one having `border: Border.all(color: t.amber, width: 2)` and larger height.

Theme toggle row (glass settings): 
```dart
ListTile(
  leading: Icon(LucideIcons.palette, color: t.muted),
  title: Text('Sports Ticker Theme', style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600)),
  trailing: Switch(
    value: ref.watch(themeProvider) == ThemeVariant.sport,
    activeColor: t.red,
    onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
  ),
),
```

- [ ] **Step 2: Verify and commit**

```bash
git add lib/features/profile/screens/profile_screen.dart
git commit -m "feat: restyle ProfileScreen with Player Card + theme toggle"
```

---

## Task 14: Owner Registration Wizard

**Files:**
- Modify: `lib/features/admin/screens/add_gym_screen.dart`

**Design reference:** `docs/design/screens-sport.jsx` → `SpRegister`; `docs/design/screens.jsx` → `ScreenRegister`.

3-step wizard:
- Step 1: Basic Info (gym name, type, website)
- Step 2: Location (address autocomplete)
- Step 3: Confirm (summary card)

**Sport layout:** Step indicator as 3 blocks with amber active block + step number. Form inputs as dark-bordered sharp containers. "Next" button = SpButton (full width, `t.red`). Steps slide via `PageView`.

**Glass layout:** Step indicator as colored dots with label. Glass card inputs. Rounded button.

- [ ] **Step 1: Read existing add_gym_screen.dart, then replace with 3-step wizard**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';

class AddGymScreen extends ConsumerStatefulWidget {
  const AddGymScreen({super.key});

  @override
  ConsumerState<AddGymScreen> createState() => _AddGymScreenState();
}

class _AddGymScreenState extends ConsumerState<AddGymScreen> {
  final _pageCtrl = PageController();
  int _step = 0;

  final _nameCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  String _gymType = 'gi';

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Container(
            color: t.isSport ? t.bg2 : Colors.transparent,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(children: [
              GestureDetector(onTap: _back, child: Icon(LucideIcons.arrowLeft, size: 20, color: t.text)),
              const SizedBox(width: 12),
              Expanded(child: Text('Register Gym', style: t.h1Style.copyWith(fontSize: 20))),
            ]),
          ),
          // Step indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: t.isSport
                ? Row(children: List.generate(3, (i) => Expanded(
                    child: Container(
                      height: 28,
                      margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      color: i == _step ? t.amber : i < _step ? t.green : t.surface,
                      child: Center(child: Text(
                        i < _step ? '✓' : '${i + 1}',
                        style: t.miniStyle.copyWith(color: i == _step ? t.bg : i < _step ? t.bg : t.muted),
                      )),
                    ),
                  )))
                : Row(children: List.generate(3, (i) {
                    final labels = ['Basic Info', 'Location', 'Confirm'];
                    return Expanded(child: Column(children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: i <= _step ? t.red : t.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: i == _step ? t.red : t.border),
                        ),
                        child: Center(child: Text(
                          i < _step ? '✓' : '${i + 1}',
                          style: t.miniStyle.copyWith(color: i <= _step ? Colors.white : t.muted),
                        )),
                      ),
                      const SizedBox(height: 4),
                      Text(labels[i], style: t.miniStyle.copyWith(fontSize: 9, color: i <= _step ? t.text : t.muted)),
                    ]));
                  })),
          ),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1(t: t, nameCtrl: _nameCtrl, websiteCtrl: _websiteCtrl, gymType: _gymType, onTypeChange: (v) => setState(() => _gymType = v)),
                _Step2(t: t, addressCtrl: _addressCtrl, cityCtrl: _cityCtrl),
                _Step3(t: t, name: _nameCtrl.text, address: _addressCtrl.text, gymType: _gymType),
              ],
            ),
          ),
          // Next button
          Container(
            color: t.isSport ? t.bg2 : Colors.transparent,
            padding: const EdgeInsets.all(16),
            child: t.isSport
                ? GestureDetector(
                    onTap: _next,
                    child: Container(
                      width: double.infinity, height: 54,
                      color: t.red,
                      child: Center(child: Text(
                        _step < 2 ? 'Next Step' : 'Register Gym',
                        style: t.h2Style.copyWith(color: Colors.white, fontSize: 16),
                      )),
                    ),
                  )
                : ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.red,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.cardRadius)),
                    ),
                    child: Text(_step < 2 ? 'Continue' : 'Register Gym',
                        style: t.h2Style.copyWith(color: Colors.white)),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _Step1 extends StatelessWidget {
  final AppTokens t;
  final TextEditingController nameCtrl;
  final TextEditingController websiteCtrl;
  final String gymType;
  final void Function(String) onTypeChange;

  const _Step1({required this.t, required this.nameCtrl, required this.websiteCtrl, required this.gymType, required this.onTypeChange});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Basic Info', style: t.h2Style),
        const SizedBox(height: 16),
        _Field(t: t, label: 'Gym Name', ctrl: nameCtrl, hint: 'e.g. Atos HQ'),
        const SizedBox(height: 12),
        _Field(t: t, label: 'Website', ctrl: websiteCtrl, hint: 'https://…'),
        const SizedBox(height: 16),
        Text('Gi Type', style: t.labelStyle),
        const SizedBox(height: 8),
        Row(children: [
          for (final opt in [('gi', 'Gi'), ('nogi', 'No-Gi'), ('both', 'Both')])
            Expanded(child: GestureDetector(
              onTap: () => onTypeChange(opt.$1),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: gymType == opt.$1 ? t.giColor(opt.$1).withOpacity(0.15) : t.surface,
                  border: Border.all(color: gymType == opt.$1 ? t.giColor(opt.$1) : t.border, width: gymType == opt.$1 ? 2 : 1),
                  borderRadius: BorderRadius.circular(t.cardRadius),
                ),
                child: Text(opt.$2, textAlign: TextAlign.center,
                    style: t.miniStyle.copyWith(color: gymType == opt.$1 ? t.giColor(opt.$1) : t.muted)),
              ),
            )),
        ]),
      ]),
    );
  }
}

class _Step2 extends StatelessWidget {
  final AppTokens t;
  final TextEditingController addressCtrl;
  final TextEditingController cityCtrl;

  const _Step2({required this.t, required this.addressCtrl, required this.cityCtrl});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Location', style: t.h2Style),
        const SizedBox(height: 16),
        _Field(t: t, label: 'Street Address', ctrl: addressCtrl, hint: '123 Main St'),
        const SizedBox(height: 12),
        _Field(t: t, label: 'City / State', ctrl: cityCtrl, hint: 'Los Angeles, CA'),
      ]),
    );
  }
}

class _Step3 extends StatelessWidget {
  final AppTokens t;
  final String name;
  final String address;
  final String gymType;

  const _Step3({required this.t, required this.name, required this.address, required this.gymType});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Confirm', style: t.h2Style),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(t.cardRadius),
            border: Border.all(color: t.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.isEmpty ? 'Gym Name' : name, style: t.h1Style.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Text(address.isEmpty ? 'Address' : address, style: t.bodyStyle),
          ]),
        ),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final AppTokens t;
  final String label;
  final TextEditingController ctrl;
  final String hint;

  const _Field({required this.t, required this.label, required this.ctrl, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: t.labelStyle),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: t.border),
        ),
        child: TextField(
          controller: ctrl,
          style: t.bodyStyle,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: t.miniStyle.copyWith(fontSize: 13),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ),
    ]);
  }
}
```

- [ ] **Step 2: Verify and commit**

```bash
git add lib/features/admin/screens/add_gym_screen.dart
git commit -m "feat: restyle AddGymScreen as 3-step registration wizard"
```

---

## Task 15: CreateSessionScreen

**Files:**
- Modify: `lib/features/admin/screens/create_session_screen.dart`

**Design reference:** `docs/design/screens-sport.jsx` → `SpCreate`; `docs/design/screens.jsx` → `ScreenCreate`.

**Layout (both themes):**
1. Header "Create Open Mat" with back button
2. Form fields: Session Name, Gi Type selector (GiBadge-style toggle), Experience Level selector, Date picker, Start/End time, Mat Fee (number input), Description, Max Participants
3. Submit button

Read the existing `create_session_screen.dart` first, then restyle it using:
- `AppTokens` for all colors
- `_Field` helper (same pattern as `_Step1` in Task 14)
- Gi type row selector = row of 3 bordered containers toggling via state
- Exp level selector = row of 4 bordered containers
- All inputs using `t.surface` background, `t.border`, `t.cardRadius`
- Submit button = same sport/glass conditional as previous tasks

- [ ] **Step 1: Implement the restyled create_session_screen.dart following the pattern above.**

- [ ] **Step 2: Verify and commit**

```bash
git add lib/features/admin/screens/create_session_screen.dart
git commit -m "feat: restyle CreateSessionScreen to match designs"
```

---

## Task 16: Update router to remove unused placeholder screens + final build check

**Files:**
- Modify: `lib/app/router.dart`
- Modify: `lib/features/training/screens/my_training_screen.dart`
- Modify: `lib/features/favorites/screens/favorites_screen.dart`
- Modify: `lib/features/notifications/screens/notifications_screen.dart`
- Modify: `lib/features/settings/screens/settings_screen.dart`

- [ ] **Step 1: Restyle my_training_screen.dart to match Sport/Glass**

Training screen (Sport): Masthead + stats strip (TOTAL MATS / HRS / STREAK / GYMS) + session rows list.

Training screen (Glass): Header + session cards list.

Use same `AppTokens` pattern, `SessionRow` widget, `AppBottomNav`.

- [ ] **Step 2: Restyle favorites_screen.dart**

List of favorite gyms. Each row: gym name, gi type badge, distance, heart icon to unfavorite.

- [ ] **Step 3: Restyle notifications_screen.dart**

List of notification rows. Each: icon, title, body, timestamp.

- [ ] **Step 4: Restyle settings_screen.dart**

Settings list with theme toggle (same as in ProfileScreen). Group: Notifications, Account, About, Sign Out.

- [ ] **Step 5: Full build + run check**

```bash
flutter build web --no-tree-shake-icons 2>&1 | tail -10
```

Expected: built successfully with no errors.

- [ ] **Step 6: Final commit**

```bash
git add lib/features/training/ lib/features/favorites/ lib/features/notifications/ lib/features/settings/
git commit -m "feat: restyle remaining screens to match Sport/Glass design system"
```

---

## Self-Review

**Spec coverage:**
- ✅ Sports Ticker theme tokens → Task 2
- ✅ Light Glass theme tokens → Task 2
- ✅ Theme toggle → Task 3 + Task 13 (settings)
- ✅ Barlow Condensed typography → Task 1 + 2
- ✅ GiBadge, ExpBadge, BeltBadge → Task 4
- ✅ SessionRow (both themes) → Task 5
- ✅ StatBar, ScoreCell, LiveDot, TickerStrip → Task 6
- ✅ AppBottomNav → Task 7
- ✅ HomeScreen → Task 8
- ✅ SearchScreen → Task 9
- ✅ OpenMatDetail → Task 10
- ✅ ReviewSheet → Task 11
- ✅ GymDetail → Task 12
- ✅ Profile + theme toggle → Task 13
- ✅ Registration Wizard → Task 14
- ✅ CreateSession → Task 15
- ✅ Training, Favorites, Notifications, Settings → Task 16

**Type consistency:** `AppTokens` is defined once in Task 2 and referenced identically across all tasks via `Theme.of(context).extension<AppTokens>()!`. `SessionRowData` defined in Task 5 (`lib/shared/widgets/session_row.dart`) — all screens use inline stub data with this type. `ThemeVariant` and `themeProvider` defined in Task 3 — used in Task 13. ✅

**Placeholders:** None. Every task has either complete Dart code or an explicit instruction to follow an established pattern with named widgets and token references.

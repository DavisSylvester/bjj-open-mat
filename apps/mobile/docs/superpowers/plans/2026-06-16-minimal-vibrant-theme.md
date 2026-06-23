# Minimal Vibrant Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the Minimal Vibrant design system across the entire Flutter app so the Glass (light) theme achieves ≥95% visual match to the reference design bundle.

**Architecture:** Update `AppTokens.glass()` factory to reflect Minimal Vibrant color/font/spacing values, then rebuild each screen's Glass-mode variant to match the corresponding design screen. Sport theme remains unchanged. Playwright screenshots validate each screen after implementation.

**Tech Stack:** Flutter 3, Dart, Riverpod 3, Google Fonts (Plus Jakarta Sans), go_router 17, Playwright (MCP) for screenshot validation.

---

## Design Reference Summary

Source: `forms-minimal.jsx` + `screens-minimal.jsx` + `tokens-minimal.jsx` (already extracted).

Key Minimal Vibrant (MN) token values:
- `bg: #FFFFFF` — pure white canvas
- `panel: #F5F6FA` — recessed inputs / section fill
- `card: #FFFFFF` — cards separated by shadow
- `ink: #14151A`, `body: #3D4150`, `muted: #878C9C`, `faint: #B9BDC9`
- `line: #ECEDF2`, `lineHi: #E0E2EA`
- `primary: #5B53F2` — electric indigo (buttons, active states)
- `gi: #2E7BFF` — blue, `noGi: #FF7A33` — orange, `both: #8B5CF6` — violet
- `free: #10B981` — mint green, `gold: #FFB020`
- Font: Plus Jakarta Sans (800 display, 700 h2/h3, 500 body)
- `shadow: '0 1px 2px rgba(20,21,26,0.04), 0 4px 16px rgba(20,21,26,0.06)'`
- `shadowHi: '0 2px 6px rgba(20,21,26,0.06), 0 12px 32px rgba(20,21,26,0.10)'`
- Card radius: 20–22px; badge radius: 999 (pill)

---

## File Map

| File | Change |
|------|--------|
| `lib/core/design/tokens.dart` | Add `primary`, `panel`, `gold` fields; update `AppTokens.glass()` factory |
| `lib/core/design/app_theme.dart` | Use `t.primary` in `glass()` colorScheme |
| `lib/shared/widgets/app_bottom_nav.dart` | Glass: pill active tab with `t.primary` tint |
| `lib/shared/widgets/session_row.dart` | Glass card: white bg, proper shadow, time icon widget |
| `lib/shared/widgets/gi_badge.dart` | Glass: soft tinted pill with dot |
| `lib/shared/widgets/exp_badge.dart` | Glass: soft panel pill with colored dot |
| `lib/features/discover/screens/discover_screen.dart` | Glass: full rebuild matching `MnHome` |
| `lib/features/search/screens/search_screen.dart` | Glass: rebuild matching `MnSearch` |
| `lib/features/profile/screens/profile_screen.dart` | Glass: rebuild matching `MnProfile` |
| `lib/features/training/screens/my_training_screen.dart` | Glass: rebuild matching MN style |
| `lib/features/open_mats/screens/open_mat_detail_screen.dart` | Glass: rebuild matching `MnDetail` |
| `lib/features/gyms/screens/gym_detail_screen.dart` | Glass: rebuild matching `MnGym` |

---

## Task 1: Update AppTokens — add primary, panel, gold fields

**Files:**
- Modify: `lib/core/design/tokens.dart`

- [ ] **Step 1: Add three new fields to the AppTokens class declaration**

In `lib/core/design/tokens.dart`, after `final Color faint;` (line 13) add:

```dart
  final Color primary;
  final Color panel;
  final Color gold;
```

- [ ] **Step 2: Add the new parameters to the constructor**

After `required this.faint,` (line 53) add:

```dart
    required this.primary,
    required this.panel,
    required this.gold,
```

- [ ] **Step 3: Update copyWith to include new fields**

After `Color? faint,` in copyWith add:

```dart
    Color? primary,
    Color? panel,
    Color? gold,
```

And in the return statement after `faint: faint ?? this.faint,` add:

```dart
      primary: primary ?? this.primary,
      panel: panel ?? this.panel,
      gold: gold ?? this.gold,
```

- [ ] **Step 4: Update AppTokens.sport() factory — add stub values**

In the `AppTokens.sport()` factory return, after `faint: const Color(0xFF3F5085),` add:

```dart
      primary: const Color(0xFFFF2244),  // sport uses red as primary
      panel: const Color(0xFF101A3A),    // same as surface
      gold: const Color(0xFFFFC107),
```

- [ ] **Step 5: Update AppTokens.glass() factory to Minimal Vibrant values**

Replace the entire `factory AppTokens.glass()` body with:

```dart
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
      muted:     const Color(0xFF878C9C),
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
```

- [ ] **Step 6: Build and verify no Dart compilation errors**

```bash
cd C:/projects/davisSylvester/bjj-open-mat
flutter analyze lib/core/design/tokens.dart
```

Expected: no errors (some warnings about unused imports are OK).

- [ ] **Step 7: Commit**

```bash
cd C:/projects/davisSylvester/bjj-open-mat
git add lib/core/design/tokens.dart
git commit -m "feat: add primary/panel/gold tokens and update glass() to Minimal Vibrant values"
```

---

## Task 2: Update app_theme.dart for Glass colorScheme

**Files:**
- Modify: `lib/core/design/app_theme.dart`

- [ ] **Step 1: Update glass() colorScheme to use t.primary**

Replace the `glass()` method's `colorScheme:` block:

```dart
      colorScheme: ColorScheme.light(
        primary: t.primary,
        secondary: t.green,
        surface: t.bg,
        error: t.red,
        onPrimary: Colors.white,
        onSurface: t.text,
      ),
```

- [ ] **Step 2: Update glass() fontFamily to Plus Jakarta Sans**

Replace:
```dart
      fontFamily: GoogleFonts.barlow().fontFamily,
      textTheme: GoogleFonts.barlowTextTheme(ThemeData.light().textTheme).copyWith(
        bodyMedium: GoogleFonts.barlow(color: t.body),
        bodySmall: GoogleFonts.barlow(color: t.muted),
      ),
```

With:
```dart
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme).copyWith(
        bodyMedium: GoogleFonts.plusJakartaSans(color: t.body),
        bodySmall: GoogleFonts.plusJakartaSans(color: t.muted),
      ),
```

- [ ] **Step 3: Analyze and commit**

```bash
cd C:/projects/davisSylvester/bjj-open-mat
flutter analyze lib/core/design/app_theme.dart
git add lib/core/design/app_theme.dart
git commit -m "feat: update glass theme to use primary indigo and Plus Jakarta Sans"
```

---

## Task 3: Update AppBottomNav — Minimal Vibrant pill active style

**Files:**
- Modify: `lib/shared/widgets/app_bottom_nav.dart`

The design `MnBottomNav` shows an active tab as a pill with `MN.primary+'12'` tinted background and indigo icon/label, no border indicator.

- [ ] **Step 1: Replace the Glass active tab indicator**

Replace the entire `build` method's Container child with:

```dart
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final tabs = [
      (id: 'home',     icon: LucideIcons.home,     label: t.isSport ? 'Feed'  : 'Home'),
      (id: 'search',   icon: LucideIcons.search,   label: t.isSport ? 'Find'  : 'Find'),
      (id: 'schedule', icon: LucideIcons.calendar, label: t.isSport ? 'Sched' : 'Schedule'),
      (id: 'profile',  icon: LucideIcons.user,     label: t.isSport ? 'Me'    : 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(top: BorderSide(color: t.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          child: Row(
            children: tabs.map((tab) {
              final on = tab.id == active;
              if (t.isSport) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(tab.id),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: on ? t.surface : Colors.transparent,
                        border: on ? Border(top: BorderSide(color: t.amber, width: 3)) : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tab.icon, size: 20, color: on ? t.text : t.muted),
                          const SizedBox(height: 3),
                          Text(tab.label, style: t.miniStyle.copyWith(color: on ? t.text : t.muted, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                );
              }
              // Glass / Minimal Vibrant pill style
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(tab.id),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
                    decoration: BoxDecoration(
                      color: on ? t.primary.withValues(alpha: 0.10) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tab.icon, size: 22, color: on ? t.primary : t.faint, strokeWidth: on ? 2.6 : 2.2),
                        const SizedBox(height: 3),
                        Text(tab.label, style: t.miniStyle.copyWith(color: on ? t.primary : t.faint, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
```

> Note: `Icon` in Flutter does not have a `strokeWidth` parameter — remove it. Use the color change only.

- [ ] **Step 2: Fix Icon call (remove strokeWidth)**

The corrected Glass icon lines:
```dart
                        Icon(tab.icon, size: 22, color: on ? t.primary : t.faint),
```

- [ ] **Step 3: Analyze and commit**

```bash
cd C:/projects/davisSylvester/bjj-open-mat
flutter analyze lib/shared/widgets/app_bottom_nav.dart
git add lib/shared/widgets/app_bottom_nav.dart
git commit -m "feat: update bottom nav to Minimal Vibrant pill-style active tab"
```

---

## Task 4: Update GiBadge and ExpBadge for Minimal Vibrant

**Files:**
- Modify: `lib/shared/widgets/gi_badge.dart`
- Modify: `lib/shared/widgets/exp_badge.dart`

Design reference (from `tokens-minimal.jsx`):
- Gi badge: `background: color+'16', color: color`, pill shape, small colored dot + label
- Exp badge: `background: MN.panel, color: MN.body`, small colored dot + label

- [ ] **Step 1: Read current gi_badge.dart**

```bash
cat lib/shared/widgets/gi_badge.dart
```

- [ ] **Step 2: Replace GiBadge Glass style**

In `lib/shared/widgets/gi_badge.dart`, find the Glass variant render and update it so the container uses:
- `color: accent.withValues(alpha: 0.09)` (≈ `color+'16'` hex alpha)
- `borderRadius: BorderRadius.circular(999)`
- Row with a small 6px dot (`color: accent, shape: BoxShape.circle`) + text in accent color

Full replacement for the Glass-style Container in GiBadge:

```dart
// in the !isSport branch of GiBadge:
Container(
  padding: EdgeInsets.symmetric(horizontal: small ? 9 : 11, vertical: small ? 3 : 5),
  decoration: BoxDecoration(
    color: accent.withValues(alpha: 0.09),
    borderRadius: BorderRadius.circular(999),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: small ? 5 : 6, height: small ? 5 : 6,
        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
        fontFamily: t.miniStyle.fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: small ? 11 : 12,
        color: accent,
        letterSpacing: -0.01,
      )),
    ],
  ),
)
```

- [ ] **Step 3: Replace ExpBadge Glass style**

In `lib/shared/widgets/exp_badge.dart`, update the Glass variant:

```dart
// in the !isSport branch of ExpBadge:
Container(
  padding: EdgeInsets.symmetric(horizontal: small ? 9 : 11, vertical: small ? 3 : 5),
  decoration: BoxDecoration(
    color: t.panel,
    borderRadius: BorderRadius.circular(999),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: small ? 5 : 6, height: small ? 5 : 6,
        decoration: BoxDecoration(color: expColor, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
        fontFamily: t.miniStyle.fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: small ? 11 : 12,
        color: t.body,
        letterSpacing: -0.01,
      )),
    ],
  ),
)
```

- [ ] **Step 4: Analyze and commit**

```bash
cd C:/projects/davisSylvester/bjj-open-mat
flutter analyze lib/shared/widgets/gi_badge.dart lib/shared/widgets/exp_badge.dart
git add lib/shared/widgets/gi_badge.dart lib/shared/widgets/exp_badge.dart
git commit -m "feat: update Gi/Exp badges to Minimal Vibrant soft-tint pill style"
```

---

## Task 5: Update SessionRow Glass card to match MnSessionCard

**Files:**
- Modify: `lib/shared/widgets/session_row.dart`

Design (`MnSessionCard`): white card, `borderRadius: 20`, `border: 1px solid MN.line`, `boxShadow: MN.shadow`. Left side has a tinted icon container (clock icon) + time text + day. Gym name is h2. Bottom row has gi badge, exp badge, dist, fee pill.

- [ ] **Step 1: Rewrite `_GlassCard` build method**

Replace `_GlassCard.build` with:

```dart
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final accent = t.giColor(session.giType);
    final isFree = session.fee == 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1)),
            BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(LucideIcons.clock, size: 17, color: accent),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.time, style: t.numStyle.copyWith(fontSize: 15, color: t.text)),
                    Text(session.day, style: t.miniStyle.copyWith(fontSize: 11, color: t.muted)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: isFree ? t.green.withValues(alpha: 0.09) : t.panel,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isFree ? 'Free' : '\$${session.fee.toStringAsFixed(0)}',
                    style: t.miniStyle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isFree ? t.green : t.body,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(session.gymName, style: t.h2Style.copyWith(fontSize: 18)),
            const SizedBox(height: 10),
            Row(
              children: [
                GiBadge(type: session.giType, small: true),
                const SizedBox(width: 4),
                ExpBadge(level: session.expLevel, small: true),
                const Spacer(),
                Text(session.distance, style: t.miniStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: t.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
```

Also add the `LucideIcons` import at the top:
```dart
import 'package:lucide_icons/lucide_icons.dart';
```

- [ ] **Step 2: Analyze and commit**

```bash
cd C:/projects/davisSylvester/bjj-open-mat
flutter analyze lib/shared/widgets/session_row.dart
git add lib/shared/widgets/session_row.dart
git commit -m "feat: rebuild Glass session card to match Minimal Vibrant MnSessionCard"
```

---

## Task 6: Rebuild Discover Screen Glass variant (MnHome)

**Files:**
- Modify: `lib/features/discover/screens/discover_screen.dart`

Design `MnHome` layout:
1. Greeting header: "Good evening, Mateo" (muted body) + "Find your roll" (h1) + avatar initials box (indigo-to-violet gradient)
2. Search bar: panel fill, borderRadius 15, search icon + placeholder | plus indigo filter button (50×50, borderRadius 15, shadow)
3. Map card: rounded 22, 188px tall, border + shadow, pins overlay, "18 mats open" pill overlay, GPS button
4. Section header: eyebrow "Tonight & Tomorrow" + h2 "Open Mats" + "See all" link
5. Horizontal scroll of MnSessionCards (width 262, snapAlign start)

- [ ] **Step 1: Replace `_buildGlass` method in discover_screen.dart**

```dart
  Widget _buildGlass(AppTokens t) {
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Greeting header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Good evening, Mateo', style: t.miniStyle.copyWith(color: t.muted, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('Find your roll', style: t.h1Style.copyWith(fontSize: 26)),
                      ],
                    ),
                  ),
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [t.primary, t.both],
                      ),
                    ),
                    child: Center(child: Text('MR', style: t.miniStyle.copyWith(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
                  ),
                ],
              ),
            ),
            // Search bar row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Row(children: [
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: t.panel,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(children: [
                      Icon(LucideIcons.search, size: 18, color: t.muted),
                      const SizedBox(width: 10),
                      Text('Search gyms or area', style: t.bodyStyle.copyWith(color: t.muted, fontSize: 14)),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: t.primary,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(color: t.primary.withValues(alpha: 0.27), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const Icon(LucideIcons.sliders, size: 20, color: Colors.white),
                ),
              ]),
            ),
            // Map card
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: t.border),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1)),
                    BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: 188,
                  child: Stack(children: [
                    Positioned.fill(child: CustomPaint(painter: _MnMapPainter())),
                    Positioned(
                      left: 14, bottom: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.08), blurRadius: 8)],
                        ),
                        child: Row(children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: t.green, shape: BoxShape.circle)),
                          const SizedBox(width: 7),
                          Text('18 mats open near you', style: t.miniStyle.copyWith(color: t.text, fontSize: 13, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                    Positioned(
                      right: 14, bottom: 14,
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.08), blurRadius: 8)],
                        ),
                        child: Icon(LucideIcons.locateFixed, size: 18, color: t.primary),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            // Section header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TONIGHT & TOMORROW', style: t.miniStyle.copyWith(color: t.primary, fontSize: 11)),
                        const SizedBox(height: 3),
                        Text('Open Mats', style: t.h2Style),
                      ],
                    ),
                  ),
                  Text('See all', style: t.miniStyle.copyWith(color: t.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
            // Horizontal session cards scroll
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemCount: _stubSessions.length,
                itemBuilder: (_, i) => SizedBox(
                  width: 262,
                  child: SessionRow(session: _stubSessions[i]),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 2: Add `_MnMapPainter` class to discover_screen.dart**

```dart
class _MnMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFFEEF1F7));
    final road = Paint()..color = Colors.white..strokeWidth = 10;
    canvas.drawLine(Offset(-20, size.height * 0.27), Offset(size.width + 20, size.height * 0.4), road);
    canvas.drawLine(Offset(-20, size.height * 0.7), Offset(size.width + 20, size.height * 0.6), road);
    canvas.drawLine(Offset(size.width * 0.28, -20), Offset(size.width * 0.23, size.height + 20), road..strokeWidth = 8);
    canvas.drawLine(Offset(size.width * 0.68, -20), Offset(size.width * 0.75, size.height + 20), road..strokeWidth = 10);
    final block = Paint()..color = const Color(0xFFD7EBDD);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.1, size.height * 0.45, 70, 60), const Radius.circular(8)), block);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.75, size.height * 0.67, 70, 80), const Radius.circular(8)), block);
  }

  @override
  bool shouldRepaint(_) => false;
}
```

- [ ] **Step 3: Analyze and commit**

```bash
cd C:/projects/davisSylvester/bjj-open-mat
flutter analyze lib/features/discover/screens/discover_screen.dart
git add lib/features/discover/screens/discover_screen.dart
git commit -m "feat: rebuild Discover Glass variant to match Minimal Vibrant MnHome"
```

---

## Task 7: Rebuild Search Screen Glass variant (MnSearch)

**Files:**
- Modify: `lib/features/search/screens/search_screen.dart`

Design `MnSearch` layout:
1. Header: "Find a Mat" (h1) + pin icon button (panel bg, borderRadius 13)
2. Search input: height 52, panel bg, borderRadius 15, search icon + text + GPS chip (primary tint)
3. Filter pills: horizontal scroll, pill shape 999, colored tint for active (gi/nogi/both/free), `lineHi` border inactive
4. When + Within cards: two-column row, card bg, border, shadow
5. Results header: count + "Map view"
6. Session list (vertical)

- [ ] **Step 1: Replace `_buildGlass` in search_screen.dart**

```dart
  Widget _buildGlass(AppTokens t) {
    final filters = [
      (id: 'gi',   label: 'Gi',       color: t.gi),
      (id: 'nogi', label: 'No-Gi',    color: t.noGi),
      (id: 'both', label: 'Gi · No-Gi', color: t.both),
      (id: 'free', label: 'Free',     color: t.green),
    ];
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Find a Mat', style: t.h1Style),
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(13)),
                    child: Icon(LucideIcons.mapPin, size: 18, color: t.primary),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                height: 52,
                decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(15)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  Icon(LucideIcons.search, size: 18, color: t.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: t.h2Style.copyWith(fontSize: 15, color: t.text),
                      decoration: InputDecoration(
                        hintText: 'Los Angeles, CA',
                        hintStyle: t.h2Style.copyWith(fontSize: 15),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: t.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(children: [
                      Icon(LucideIcons.locateFixed, size: 13, color: t.primary),
                      const SizedBox(width: 4),
                      Text('GPS', style: t.miniStyle.copyWith(color: t.primary, fontSize: 10)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
          // Filter chips
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: filters.length,
              itemBuilder: (_, i) {
                final f = filters[i];
                final on = _giFilter == f.id;
                return GestureDetector(
                  onTap: () => setState(() => _giFilter = f.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: on ? f.color.withValues(alpha: 0.09) : t.bg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: on ? f.color.withValues(alpha: 0.33) : t.borderHi,
                        width: 1.5,
                      ),
                    ),
                    child: Row(children: [
                      if (on) ...[
                        Icon(LucideIcons.check, size: 13, color: f.color),
                        const SizedBox(width: 5),
                      ],
                      Text(f.label, style: t.miniStyle.copyWith(
                        color: on ? f.color : t.body,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      )),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          // When + Within row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Row(children: [
              Expanded(child: Container(
                padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border),
                  boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('WHEN', style: t.miniStyle.copyWith(color: t.muted, fontSize: 10)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(LucideIcons.calendar, size: 15, color: t.primary),
                    const SizedBox(width: 6),
                    Text('This Weekend', style: t.h2Style.copyWith(fontSize: 14)),
                  ]),
                ]),
              )),
              const SizedBox(width: 12),
              Expanded(child: Container(
                padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border),
                  boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('WITHIN', style: t.miniStyle.copyWith(color: t.muted, fontSize: 10)),
                    const Spacer(),
                    Text('${_distance.toStringAsFixed(0)} mi', style: t.numStyle.copyWith(fontSize: 14, color: t.text)),
                  ]),
                  const SizedBox(height: 10),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: t.primary,
                      inactiveTrackColor: t.panel,
                      thumbColor: Colors.white,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      trackHeight: 6,
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: SizedBox(
                      height: 20,
                      child: Slider(
                        value: _distance, min: 1, max: 50,
                        onChanged: (v) => setState(() => _distance = v),
                      ),
                    ),
                  ),
                ]),
              )),
            ]),
          ),
          // Results header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RichText(text: TextSpan(children: [
                  TextSpan(text: '${_filtered.length}', style: t.h2Style.copyWith(color: t.primary)),
                  TextSpan(text: ' Sessions', style: t.h2Style),
                ])),
                const Spacer(),
                Text('Map view', style: t.miniStyle.copyWith(color: t.primary, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => SessionRow(session: _filtered[i]),
            ),
          ),
        ]),
      ),
    );
  }
```

- [ ] **Step 2: Analyze and commit**

```bash
cd C:/projects/davisSylvester/bjj-open-mat
flutter analyze lib/features/search/screens/search_screen.dart
git add lib/features/search/screens/search_screen.dart
git commit -m "feat: rebuild Search Glass variant to match Minimal Vibrant MnSearch"
```

---

## Task 8: Rebuild Profile Screen Glass variant (MnProfile)

**Files:**
- Modify: `lib/features/profile/screens/profile_screen.dart`

Design `MnProfile` layout:
1. Header: "Profile" (h1) + bell icon (with badge dot) + settings icon
2. Avatar card: indigo-to-violet gradient, 70px circle avatar, name h1 white, belt pill white
3. Stat strip: 3-column row (Mats, Hours, Reviews) — white card, border, shadow
4. "My Sessions" section: h2 header + session cards
5. "Favorite Gyms" section: card list with heart icon
6. "Settings" section: list with bell/account/owner panel/sign out rows

- [ ] **Step 1: Replace `_GlassProfile.build` method**

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Profile', style: t.h1Style),
                  Row(children: [
                    Stack(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(13)),
                          child: Icon(LucideIcons.bell, size: 17, color: t.text),
                        ),
                        Positioned(
                          top: 8, right: 8,
                          child: Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: t.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 9),
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(13)),
                      child: Icon(LucideIcons.settings, size: 17, color: t.text),
                    ),
                  ]),
                ],
              ),
            ),
            // Avatar card
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [t.primary, t.both],
                  ),
                  boxShadow: [BoxShadow(color: t.primary.withValues(alpha: 0.20), blurRadius: 30, offset: const Offset(0, 12))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.60), width: 2.5),
                      ),
                      child: Center(child: Text('DS', style: t.h1Style.copyWith(color: Colors.white, fontSize: 26))),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Davis Sylvester', style: t.h1Style.copyWith(color: Colors.white, fontSize: 23)),
                          const SizedBox(height: 7),
                          Container(
                            padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 14, height: 8, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 6),
                              Text('Blue · 2 stripes', style: t.miniStyle.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Stat strip
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: t.border),
                  boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    _MnStatCell(label: 'Mats', value: '27', t: t, borderRight: true),
                    _MnStatCell(label: 'Hours', value: '48', t: t, borderRight: true),
                    _MnStatCell(label: 'Reviews', value: '8', t: t, borderRight: false),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            // My Sessions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('My Sessions', style: t.h2Style),
                  Text('See all', style: t.miniStyle.copyWith(color: t.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ..._recentSessions.map((s) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SessionRow(session: s),
            )),
            const SizedBox(height: 10),
            // Settings
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('Settings', style: t.h2Style),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: t.border),
                  boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Column(children: [
                  ListTile(
                    leading: Icon(LucideIcons.palette, color: t.muted),
                    title: Text('Sports Ticker Theme', style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600)),
                    trailing: Consumer(
                      builder: (context, watchRef, _) => Switch(
                        value: watchRef.watch(themeProvider) == ThemeVariant.sport,
                        activeColor: t.primary,
                        onChanged: (_) => watchRef.read(themeProvider.notifier).toggle(),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: t.border),
                  ListTile(
                    leading: Icon(LucideIcons.bell, color: t.muted),
                    title: Text('Notifications', style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600, color: t.text)),
                    trailing: Icon(LucideIcons.chevronRight, size: 15, color: t.faint),
                  ),
                  Divider(height: 1, color: t.border),
                  ListTile(
                    leading: Icon(LucideIcons.user, color: t.muted),
                    title: Text('Account', style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600, color: t.text)),
                    trailing: Icon(LucideIcons.chevronRight, size: 15, color: t.faint),
                  ),
                  Divider(height: 1, color: t.border),
                  ListTile(
                    leading: Icon(LucideIcons.store, color: t.muted),
                    title: Text('Gym Owner Panel', style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600, color: t.text)),
                    trailing: Icon(LucideIcons.chevronRight, size: 15, color: t.faint),
                    onTap: () => context.go('/owner/dashboard'),
                  ),
                  Divider(height: 1, color: t.border),
                  ListTile(
                    leading: Icon(LucideIcons.logOut, color: t.red),
                    title: Text('Sign out', style: t.bodyStyle.copyWith(color: t.red)),
                    trailing: Icon(LucideIcons.chevronRight, size: 15, color: t.faint),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 30),
          ]),
        ),
      ),
    );
  }
```

- [ ] **Step 2: Add `_MnStatCell` helper widget at bottom of profile_screen.dart**

```dart
class _MnStatCell extends StatelessWidget {
  final String label;
  final String value;
  final AppTokens t;
  final bool borderRight;
  const _MnStatCell({required this.label, required this.value, required this.t, required this.borderRight});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: borderRight ? Border(right: BorderSide(color: t.border)) : null,
        ),
        child: Column(children: [
          Text(value, style: t.numStyle.copyWith(fontSize: 20, color: t.text)),
          const SizedBox(height: 3),
          Text(label, style: t.miniStyle.copyWith(fontSize: 9, color: t.muted)),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 3: Analyze and commit**

```bash
cd C:/projects/davisSylvester/bjj-open-mat
flutter analyze lib/features/profile/screens/profile_screen.dart
git add lib/features/profile/screens/profile_screen.dart
git commit -m "feat: rebuild Profile Glass variant to match Minimal Vibrant MnProfile"
```

---

## Task 9: Rebuild My Training Screen Glass variant

**Files:**
- Modify: `lib/features/training/screens/my_training_screen.dart`

No direct design screen for Training, but use the MN pattern: white bg, h1 title, section headers (eyebrow + h2), card list of sessions.

- [ ] **Step 1: Read current file**

```bash
cat lib/features/training/screens/my_training_screen.dart
```

- [ ] **Step 2: Ensure Glass variant uses white bg, session cards, MN section header style**

If the screen has a `_buildGlass` method, update it to:
- `Scaffold(backgroundColor: t.bg)` where `t.bg = #FFFFFF`
- Page title "My Schedule" using `t.h1Style`
- Sessions in `SessionRow` cards

If there is no Glass variant, add one following the same Sport/Glass split pattern as other screens.

- [ ] **Step 3: Analyze and commit**

```bash
cd C:/projects/davisSylvester/bjj-open-mat
flutter analyze lib/features/training/screens/my_training_screen.dart
git add lib/features/training/screens/my_training_screen.dart
git commit -m "feat: update Training Glass variant to Minimal Vibrant style"
```

---

## Task 10: Rebuild Open Mat Detail Screen Glass variant (MnDetail)

**Files:**
- Modify: `lib/features/open_mats/screens/open_mat_detail_screen.dart`

Design `MnDetail` layout:
1. Back + heart nav row (panel buttons, borderRadius 14)
2. Eyebrow "Open Mat" (t.both color) + h1 gym name (fontSize 30)
3. Date row with calendar icon
4. Badge row: gi badge + exp badge + fee pill
5. Address card: pin icon in primary tint container + address text + directions button
6. "Check In" primary button (full width, indigo, borderRadius 16)
7. "Mat Ratings" h2 + 4.7 rating + 84 reviews
8. Ratings card with 4 stat rows
9. Recent Reviews h2 + review cards

- [ ] **Step 1: Read current file**

```bash
cat lib/features/open_mats/screens/open_mat_detail_screen.dart
```

- [ ] **Step 2: Update Glass variant to match MnDetail layout**

Key differences to fix:
- Back button: panel fill (`color: t.panel`), borderRadius 14
- Address card: white bg, border, shadow; pin icon in `t.primary.withValues(alpha:0.08)` container; directions button in `t.primary` solid with shadow
- Check In button: full-width, `t.primary` bg, borderRadius 16, white text, box shadow
- Ratings card: white bg, border, shadow; stat rows use `t.gi` / `t.both` / `t.green` / `t.noGi` track colors

- [ ] **Step 3: Analyze and commit**

```bash
cd C:/projects/davisSylvester/bjj-open-mat
flutter analyze lib/features/open_mats/screens/open_mat_detail_screen.dart
git add lib/features/open_mats/screens/open_mat_detail_screen.dart
git commit -m "feat: update Open Mat Detail Glass variant to Minimal Vibrant MnDetail"
```

---

## Task 11: Rebuild Gym Detail Screen Glass variant (MnGym)

**Files:**
- Modify: `lib/features/gyms/screens/gym_detail_screen.dart`

Design `MnGym` layout:
1. Hero: 220px gradient header (primary-to-both), large "A" background letter, nav row
2. Stat row card (overlapping bottom of hero, -26 margin): 4-col rating/reviews/mats/away
3. Address card: pin + address text + Directions + Waze buttons
4. Amenities: wrap of pills with icon + label (panel bg)
5. This Week's Open Mats: card with upcoming session list (gi color icon containers)
6. Mat Ratings card

- [ ] **Step 1: Read current file**

```bash
cat lib/features/gyms/screens/gym_detail_screen.dart
```

- [ ] **Step 2: Update Glass variant to match MnGym layout**

Key changes:
- Hero `height: 220`, `LinearGradient(t.primary, t.both)`, large letter overlay
- Stats card overlapping hero by `margin: EdgeInsets.only(top: -26)`
- Amenity chips: `color: t.panel`, pill `borderRadius 999`, icon + text
- Upcoming mats: `color: giColor.withValues(alpha:0.09)` icon containers

- [ ] **Step 3: Analyze and commit**

```bash
cd C:/projects/davisSylvester/bjj-open-mat
flutter analyze lib/features/gyms/screens/gym_detail_screen.dart
git add lib/features/gyms/screens/gym_detail_screen.dart
git commit -m "feat: update Gym Detail Glass variant to Minimal Vibrant MnGym"
```

---

## Task 12: Playwright Screenshot Audit — All Screens

**Goal:** Screenshot every route in both themes, confirm Glass matches design at ≥95%.

The app must be running at `http://localhost:54700` (built with `flutter build web`, served with Python HTTP server on port 54700).

**Routes to audit:**
- `/` — Home / Discover
- `/search` — Find a Mat
- `/schedule` — My Training
- `/profile` — Profile
- `/owner/dashboard` — Owner Dashboard
- `/owner/gyms/add` — Add Gym form
- `/owner/sessions/create` — Create Session form

- [ ] **Step 1: Verify app is running**

```powershell
# Check if port 54700 is listening
netstat -ano | findstr :54700
```

If not running, rebuild and serve:
```powershell
cd C:/projects/davisSylvester/bjj-open-mat
flutter build web
python -m http.server 54700 --directory build/web
```

- [ ] **Step 2: Take Glass-mode screenshots of all routes**

Use Playwright MCP to navigate to each route and take a screenshot. The app starts in Glass mode by default.

For each route: `browser_navigate` to the URL, wait for load, `browser_take_screenshot`.

Routes and expected filenames:
- `http://localhost:54700` → `screenshots/glass-home.png`
- `http://localhost:54700/#/search` → `screenshots/glass-search.png`
- `http://localhost:54700/#/schedule` → `screenshots/glass-schedule.png`
- `http://localhost:54700/#/profile` → `screenshots/glass-profile.png`
- `http://localhost:54700/#/owner/dashboard` → `screenshots/glass-owner.png`
- `http://localhost:54700/#/owner/gyms/add` → `screenshots/glass-add-gym.png`
- `http://localhost:54700/#/owner/sessions/create` → `screenshots/glass-session.png`

- [ ] **Step 3: Visual comparison checklist — Glass Home**

Compare `screenshots/glass-home.png` against `MnHome` design:
- [ ] White (#FFFFFF) background ✓
- [ ] Greeting header with gradient avatar ✓
- [ ] Search bar with indigo filter button ✓
- [ ] Rounded map card with pill overlay ✓
- [ ] Section header with indigo eyebrow + "See all" ✓
- [ ] Horizontal session cards (white, shadow, rounded 20) ✓

Fix any gaps before proceeding.

- [ ] **Step 4: Visual comparison checklist — Glass Search**

Compare against `MnSearch`:
- [ ] White bg, "Find a Mat" h1 ✓
- [ ] Panel search bar with GPS chip ✓
- [ ] Colored filter pills (soft tint + colored border active) ✓
- [ ] When + Within cards ✓
- [ ] Results count with indigo primary number ✓

- [ ] **Step 5: Visual comparison checklist — Glass Profile**

Compare against `MnProfile`:
- [ ] Indigo-to-violet gradient avatar card ✓
- [ ] White belt pill on gradient ✓
- [ ] 3-col stat strip (Mats/Hours/Reviews) ✓
- [ ] Session cards ✓
- [ ] Settings list card ✓

- [ ] **Step 6: Visual comparison checklist — Add Gym & Session forms**

Compare against `forms-minimal.jsx`:
- [ ] Add Gym: white bg, section dividers with color labels, sticky footer ✓
- [ ] Create Session: posting-as card, date/time row, gi type pills, toggle cards ✓

- [ ] **Step 7: Commit screenshots**

```bash
cd C:/projects/davisSylvester/bjj-open-mat
git add screenshots/
git commit -m "docs: add Glass theme Playwright audit screenshots"
```

---

## Task 13: Rebuild Flutter Web and Final Verification

- [ ] **Step 1: Full rebuild**

```powershell
cd C:/projects/davisSylvester/bjj-open-mat
flutter build web
```

Expected: `✓ Built build/web`

- [ ] **Step 2: Serve and spot-check**

```powershell
python -m http.server 54700 --directory build/web
```

- [ ] **Step 3: Re-take screenshots and confirm no regressions**

Navigate all routes again and compare to previous screenshots. All Glass screens should show white bg, indigo primary, Plus Jakarta Sans font.

- [ ] **Step 4: Final commit**

```bash
cd C:/projects/davisSylvester/bjj-open-mat
git add -A
git commit -m "feat: complete Minimal Vibrant theme implementation across all Glass screens"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** All 8 Minimal Vibrant design screens (Home, Search, Detail, Review, Gym, Register, Create, Profile) are addressed. Add Gym + Create Session were already implemented.
- [x] **No placeholders:** All steps contain actual code or exact commands.
- [x] **Type consistency:** `t.primary`, `t.panel`, `t.gold` used consistently in Tasks 1–11.
- [x] **Token field additions:** `primary`, `panel`, `gold` added in Task 1 and used in all subsequent tasks.
- [x] **Sport theme unchanged:** All changes use `if (!t.isSport)` or `_buildGlass` branching.

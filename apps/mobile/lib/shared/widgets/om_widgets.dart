import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Gi Type Badge
// ─────────────────────────────────────────────────────────────────────────────

enum GiType { gi, nogi, both }

class GiBadge extends StatelessWidget {
  final GiType type;
  final bool small;

  const GiBadge({super.key, this.type = GiType.gi, this.small = false});

  static Color colorFor(GiType t) {
    switch (t) {
      case GiType.gi:   return OMColors.gi;
      case GiType.nogi: return OMColors.noGi;
      case GiType.both: return OMColors.both;
    }
  }

  static String labelFor(GiType t) {
    switch (t) {
      case GiType.gi:   return 'Gi';
      case GiType.nogi: return 'No-Gi';
      case GiType.both: return 'Gi + No-Gi';
    }
  }

  static IconData iconFor(GiType t) {
    switch (t) {
      case GiType.gi:   return Icons.sports_martial_arts;
      case GiType.nogi: return Icons.dry_cleaning;
      case GiType.both: return Icons.compare_arrows;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(type);
    final label = labelFor(type);
    final iconSize = small ? 11.0 : 13.0;
    final fontSize = small ? 10.0 : 11.0;
    final vPad = small ? 2.0 : 4.0;
    final hPad = small ? 8.0 : 10.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.165),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.333)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFor(type), size: iconSize, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'BarlowCondensed',
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
              letterSpacing: 0.08,
              color: color,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Experience Level Badge
// ─────────────────────────────────────────────────────────────────────────────

enum ExpLevel { all, beginner, intermediate, advanced }

class ExpBadge extends StatelessWidget {
  final ExpLevel level;
  final bool small;

  const ExpBadge({super.key, this.level = ExpLevel.all, this.small = false});

  static Color colorFor(ExpLevel l) {
    switch (l) {
      case ExpLevel.all:          return OMColors.allLevels;
      case ExpLevel.beginner:     return OMColors.beginner;
      case ExpLevel.intermediate: return OMColors.intermediate;
      case ExpLevel.advanced:     return OMColors.advanced;
    }
  }

  static String labelFor(ExpLevel l) {
    switch (l) {
      case ExpLevel.all:          return 'All Levels';
      case ExpLevel.beginner:     return 'Beginner';
      case ExpLevel.intermediate: return 'Intermediate';
      case ExpLevel.advanced:     return 'Advanced';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(level);
    final label = labelFor(level);
    final dotSize = small ? 5.0 : 6.0;
    final fontSize = small ? 10.0 : 11.0;
    final vPad = small ? 2.0 : 4.0;
    final hPad = small ? 8.0 : 10.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.133),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.267)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'BarlowCondensed',
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
              letterSpacing: 0.08,
              color: color,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Belt Rank Badge
// ─────────────────────────────────────────────────────────────────────────────

class BeltBadge extends StatelessWidget {
  final String belt;
  final int stripes;
  final bool small;

  const BeltBadge({super.key, this.belt = 'white', this.stripes = 0, this.small = false});

  @override
  Widget build(BuildContext context) {
    final data = BeltColors.beltData[belt.toLowerCase()] ?? BeltColors.beltData['white']!;
    final bg = data['bg']!;
    final stripe = data['stripe']!;
    final fg = data['fg']!;
    final height = small ? 18.0 : 22.0;
    final fontSize = small ? 10.0 : 12.0;
    final hPad = small ? 8.0 : 10.0;
    final stripeWidth = small ? 12.0 : 16.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              color: bg,
              child: Center(
                child: Text(
                  '${belt[0].toUpperCase()}${belt.substring(1)} Belt',
                  style: TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontWeight: FontWeight.w700,
                    fontSize: fontSize,
                    letterSpacing: 0.1,
                    color: fg,
                    height: 1,
                  ),
                ),
              ),
            ),
            Container(
              width: stripeWidth,
              color: stripe,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(stripes, (_) => Container(
                  width: 2,
                  height: small ? 10.0 : 12.0,
                  margin: const EdgeInsets.symmetric(horizontal: 0.75),
                  color: Colors.white,
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Star Rating Row
// ─────────────────────────────────────────────────────────────────────────────

class StarRow extends StatelessWidget {
  final String label;
  final double value;
  final int? count;
  final bool interactive;
  final ValueChanged<int>? onChanged;

  const StarRow({
    super.key,
    required this.label,
    this.value = 0,
    this.count,
    this.interactive = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Barlow',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: OMColors.muted,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = i < value.round();
                  return GestureDetector(
                    onTap: interactive ? () => onChanged?.call(i + 1) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Icon(
                        filled ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: interactive ? 22 : 14,
                        color: filled ? OMColors.star : OMColors.faint,
                      ),
                    ),
                  );
                }),
              ),
              if (!interactive) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(
                      fontFamily: 'BarlowCondensed',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: OMColors.text,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
              if (count != null) ...[
                const SizedBox(width: 4),
                Text(
                  '($count)',
                  style: const TextStyle(
                    fontFamily: 'Barlow',
                    fontSize: 11,
                    color: OMColors.muted,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session Data Model (local display model)
// ─────────────────────────────────────────────────────────────────────────────

class SessionData {
  final String id;
  final String gym;
  final String time;
  final String day;
  final String dist;
  final GiType gi;
  final ExpLevel exp;
  final int fee;

  const SessionData({
    required this.id,
    required this.gym,
    required this.time,
    required this.day,
    required this.dist,
    required this.gi,
    required this.exp,
    required this.fee,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Session Card
// ─────────────────────────────────────────────────────────────────────────────

class OMSessionCard extends StatelessWidget {
  final SessionData session;
  final double? width;
  final bool compact;
  final VoidCallback? onTap;

  const OMSessionCard({
    super.key,
    required this.session,
    this.width,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = GiBadge.colorFor(session.gi);
    final vPad = compact ? 11.0 : 13.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xB3FFFFFF), Color(0x8CFFFFFF)],
            stops: [0.0, 0.4],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: OMColors.borderDark),
          boxShadow: const [
            BoxShadow(color: Color(0x0FE4E4E4), blurRadius: 2, offset: Offset(0, 1)),
            BoxShadow(color: Color(0x14141428), blurRadius: 18, offset: Offset(0, 6)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Accent top stripe
            Container(height: 3, color: accentColor),
            Padding(
              padding: EdgeInsets.fromLTRB(14, vPad, 14, vPad + 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: time + distance
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 13, color: accentColor),
                      const SizedBox(width: 5),
                      Text(
                        session.time,
                        style: const TextStyle(
                          fontFamily: 'BarlowCondensed',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: OMColors.text,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '· ${session.day}',
                        style: const TextStyle(
                          fontFamily: 'Barlow',
                          fontSize: 12,
                          color: OMColors.muted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        session.dist,
                        style: const TextStyle(
                          fontFamily: 'Barlow',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: OMColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Row 2: gym name
                  Text(
                    session.gym,
                    style: const TextStyle(
                      fontFamily: 'BarlowCondensed',
                      fontWeight: FontWeight.w700,
                      fontSize: 19,
                      color: OMColors.text,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Row 3: badges
                  Row(
                    children: [
                      GiBadge(type: session.gi, small: true),
                      const SizedBox(width: 6),
                      ExpBadge(level: session.exp, small: true),
                      const Spacer(),
                      _FeeBadge(fee: session.fee),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeeBadge extends StatelessWidget {
  final int fee;
  const _FeeBadge({required this.fee});

  @override
  Widget build(BuildContext context) {
    final isFree = fee == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isFree
            ? OMColors.teal.withValues(alpha: 0.133)
            : const Color(0x0D141428),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isFree ? 'Free' : '\$$fee',
        style: TextStyle(
          fontFamily: 'BarlowCondensed',
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.08,
          color: isFree ? OMColors.teal : OMColors.body,
          height: 1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Primary CTA Button
// ─────────────────────────────────────────────────────────────────────────────

class PrimaryBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool full;
  final Color? color;
  final VoidCallback? onTap;

  const PrimaryBtn({
    super.key,
    required this.label,
    this.icon,
    this.full = false,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? OMColors.crimson;
    Widget inner = Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.333),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'BarlowCondensed',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 0.1,
              color: Colors.white,
              height: 1,
            ),
          ),
        ],
      ),
    );
    if (full) inner = SizedBox(width: double.infinity, child: inner);
    return GestureDetector(onTap: onTap, child: inner);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Bottom Nav Bar
// ─────────────────────────────────────────────────────────────────────────────

class OMBottomNav extends StatelessWidget {
  final int selectedIndex;
  final bool isOwner;
  final ValueChanged<int> onTap;
  final VoidCallback? onAdd;

  const OMBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.isOwner = false,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = isOwner
        ? const [
            _NavTab(icon: Icons.dashboard_rounded, label: 'Dashboard'),
            _NavTab(icon: Icons.store_rounded, label: 'Gyms'),
            _NavTab(icon: Icons.event_rounded, label: 'Sessions'),
            _NavTab(icon: Icons.person_rounded, label: 'Profile'),
          ]
        : const [
            _NavTab(icon: Icons.explore_rounded, label: 'Home'),
            _NavTab(icon: Icons.search_rounded, label: 'Search'),
            _NavTab(icon: Icons.fitness_center_rounded, label: 'Training'),
            _NavTab(icon: Icons.person_rounded, label: 'Profile'),
          ];

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                OMColors.bg.withValues(alpha: 1),
                OMColors.bg.withValues(alpha: 0.93),
                OMColors.bg.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
            border: const Border(
              top: BorderSide(color: OMColors.borderDark),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Left two tabs
                  ...List.generate(2, (i) {
                    final selected = i == selectedIndex;
                    final tab = tabs[i];
                    return GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? OMColors.crimson.withValues(alpha: 0.094)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tab.icon,
                              size: 22,
                              color: selected ? OMColors.crimson : OMColors.muted,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tab.label,
                              style: TextStyle(
                                fontFamily: 'BarlowCondensed',
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                letterSpacing: 0.12,
                                color: selected ? OMColors.crimson : OMColors.muted,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  // Center "+" action button — not a selectable tab
                  GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: OMColors.crimson,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: OMColors.crimson.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 28),
                    ),
                  ),
                  // Right two tabs
                  ...List.generate(2, (j) {
                    final i = j + 2;
                    final selected = i == selectedIndex;
                    final tab = tabs[i];
                    return GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? OMColors.crimson.withValues(alpha: 0.094)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tab.icon,
                              size: 22,
                              color: selected ? OMColors.crimson : OMColors.muted,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tab.label,
                              style: TextStyle(
                                fontFamily: 'BarlowCondensed',
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                letterSpacing: 0.12,
                                color: selected ? OMColors.crimson : OMColors.muted,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  final IconData icon;
  final String label;
  const _NavTab({required this.icon, required this.label});
}

// ─────────────────────────────────────────────────────────────────────────────
// Dark glass pill button (secondary/overlay variant)
// ─────────────────────────────────────────────────────────────────────────────

class DarkPillButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const DarkPillButton({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xD914182E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: OMColors.borderHi),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Eyebrow text style helper
// ─────────────────────────────────────────────────────────────────────────────

TextStyle omEyebrow({Color color = OMColors.muted, double size = 11}) => TextStyle(
  fontFamily: 'BarlowCondensed',
  fontWeight: FontWeight.w700,
  fontSize: size,
  letterSpacing: 0.14,
  color: color,
  height: 1,
);

TextStyle omH1({Color color = OMColors.text, double size = 32}) => TextStyle(
  fontFamily: 'BarlowCondensed',
  fontWeight: FontWeight.w700,
  fontSize: size,
  letterSpacing: 0.01,
  color: color,
  height: 1.0,
);

TextStyle omH2({Color color = OMColors.text, double size = 22}) => TextStyle(
  fontFamily: 'BarlowCondensed',
  fontWeight: FontWeight.w700,
  fontSize: size,
  letterSpacing: 0.02,
  color: color,
  height: 1.05,
);

TextStyle omNum({Color color = OMColors.text, double size = 14}) => TextStyle(
  fontFamily: 'BarlowCondensed',
  fontWeight: FontWeight.w700,
  fontSize: size,
  letterSpacing: 0.01,
  color: color,
  height: 1,
);

TextStyle omBody({Color color = OMColors.body, double size = 14}) => TextStyle(
  fontFamily: 'Barlow',
  fontWeight: FontWeight.w400,
  fontSize: size,
  color: color,
  height: 1.45,
);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/theme_provider.dart';
import '../../../shared/widgets/belt_badge.dart';
import '../../../shared/widgets/score_cell.dart';
import '../../../shared/widgets/session_row.dart';

final _recentSessions = [
  SessionRowData(gymName: 'Atos HQ', giType: 'gi', expLevel: 'all', time: '7:00 PM', day: 'Mon', distance: '1.2 mi', fee: 0),
  SessionRowData(gymName: 'Renzo Westwood', giType: 'nogi', expLevel: 'int', time: '8:00 PM', day: 'Sat', distance: '2.4 mi', fee: 15),
  SessionRowData(gymName: 'Gracie Barra Pasadena', giType: 'gi', expLevel: 'beg', time: '9:00 AM', day: 'Sun', distance: '4.5 mi', fee: 0),
];

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return t.isSport ? _SportProfile(t: t) : _GlassProfile(t: t, ref: ref);
  }
}

class _SportProfile extends StatelessWidget {
  final AppTokens t;
  const _SportProfile({required this.t});

  @override
  Widget build(BuildContext context) {
    final belts = ['white', 'blue', 'purple', 'brown', 'black'];
    const currentBelt = 'blue';

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          // Player card hero
          Container(
            color: t.bg2,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('#0027', style: t.miniStyle.copyWith(color: t.amber, fontSize: 10)),
              const SizedBox(height: 4),
              Text('Davis S.', style: t.h1Style.copyWith(fontSize: 32)),
              const SizedBox(height: 8),
              const BeltBadge(belt: 'blue', stripes: 2),
            ]),
          ),
          Divider(height: 1, color: t.border),
          // Stat grid
          Container(
            color: t.surfaceHi,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ScoreCell(label: 'Mats', value: '47'),
                Container(width: 1, height: 40, color: t.border),
                ScoreCell(label: 'Hours', value: '94'),
                Container(width: 1, height: 40, color: t.border),
                ScoreCell(label: 'Gyms', value: '8'),
                Container(width: 1, height: 40, color: t.border),
                ScoreCell(label: 'Reviews', value: '12'),
              ],
            ),
          ),
          Divider(height: 1, color: t.border),
          // Belt progression
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: belts.map((belt) {
              final isActive = belt == currentBelt;
              final bg = t.beltBg[belt] ?? Colors.grey;
              return Expanded(child: Container(
                height: isActive ? 22 : 16,
                margin: EdgeInsets.only(right: belt != belts.last ? 2 : 0),
                decoration: BoxDecoration(
                  color: bg,
                  border: isActive ? Border.all(color: t.amber, width: 2) : null,
                ),
              ));
            }).toList()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Row(children: [
              Container(width: 4, height: 18, color: t.red, margin: const EdgeInsets.only(right: 8)),
              Text('Recent Sessions', style: t.h2Style.copyWith(fontSize: 14)),
            ]),
          ),
          Divider(height: 1, color: t.border),
          Expanded(
            child: ListView.separated(
              itemCount: _recentSessions.length + 1,
              separatorBuilder: (context, index) => Divider(height: 1, color: t.border),
              itemBuilder: (ctx, i) {
                if (i < _recentSessions.length) return SessionRow(session: _recentSessions[i]);
                return GestureDetector(
                  onTap: () => ctx.go('/owner/dashboard'),
                  child: Container(
                    color: t.bg2,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(children: [
                      Container(width: 4, height: 18, color: t.amber, margin: const EdgeInsets.only(right: 8)),
                      Icon(LucideIcons.store, size: 16, color: t.amber),
                      const SizedBox(width: 8),
                      Text('Gym Owner Panel', style: t.miniStyle.copyWith(color: t.amber, fontSize: 11)),
                      const Spacer(),
                      Icon(LucideIcons.chevronRight, size: 14, color: t.muted),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _GlassProfile extends StatelessWidget {
  final AppTokens t;
  final WidgetRef ref;
  const _GlassProfile({required this.t, required this.ref});

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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(13)),
                          child: Icon(LucideIcons.bell, size: 17, color: t.text),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
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
                      width: 40,
                      height: 40,
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
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [t.primary, t.both],
                  ),
                  boxShadow: [BoxShadow(color: t.primary.withValues(alpha: 0.20), blurRadius: 30, offset: const Offset(0, 12))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
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
              child: Align(alignment: Alignment.centerLeft, child: Text('Settings', style: t.h2Style)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
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
                        activeThumbColor: t.primary,
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
}

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

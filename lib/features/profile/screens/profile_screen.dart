import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/theme_provider.dart';
import '../../../shared/widgets/belt_badge.dart';
import '../../../shared/widgets/score_cell.dart';
import '../../../shared/widgets/session_row.dart';
import '../../../shared/widgets/app_bottom_nav.dart';

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
    return t.isSport ? _SportProfile(t: t, ref: ref) : _GlassProfile(t: t, ref: ref);
  }
}

class _SportProfile extends StatelessWidget {
  final AppTokens t;
  final WidgetRef ref;
  const _SportProfile({required this.t, required this.ref});

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
              itemCount: _recentSessions.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: t.border),
              itemBuilder: (_, i) => SessionRow(session: _recentSessions[i]),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: AppBottomNav(active: 'profile', onTap: (_) {}),
    );
  }
}

class _GlassProfile extends StatelessWidget {
  final AppTokens t;
  final WidgetRef ref;
  const _GlassProfile({required this.t, required this.ref});

  @override
  Widget build(BuildContext context) {
    final variant = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(children: [
            // Avatar card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [t.gi.withValues(alpha: 0.3), t.both.withValues(alpha: 0.2)],
                ),
                borderRadius: BorderRadius.circular(t.cardRadius),
                border: Border.all(color: t.border),
              ),
              child: Column(children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: t.surfaceHi,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.borderHi, width: 2),
                  ),
                  child: Center(child: Text('DS', style: t.h1Style.copyWith(fontSize: 26))),
                ),
                const SizedBox(height: 12),
                Text('Davis S.', style: t.h1Style.copyWith(fontSize: 22)),
                const SizedBox(height: 8),
                const BeltBadge(belt: 'blue', stripes: 2),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _StatPill(label: '47 Mats', t: t),
                  const SizedBox(width: 8),
                  _StatPill(label: '94 Hours', t: t),
                  const SizedBox(width: 8),
                  _StatPill(label: '8 Gyms', t: t),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(children: [
                Text('My Sessions', style: t.h2Style),
              ]),
            ),
            ..._recentSessions.map((s) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SessionRow(session: s),
            )),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Settings', style: t.h2Style),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(t.cardRadius),
                border: Border.all(color: t.border),
              ),
              child: Column(children: [
                ListTile(
                  leading: Icon(LucideIcons.palette, color: t.muted),
                  title: Text('Sports Ticker Theme', style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600)),
                  trailing: Switch(
                    value: variant == ThemeVariant.sport,
                    activeThumbColor: t.red,
                    onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
                  ),
                ),
                Divider(height: 1, color: t.border),
                ListTile(
                  leading: Icon(LucideIcons.bell, color: t.muted),
                  title: Text('Notifications', style: t.bodyStyle),
                  trailing: Icon(LucideIcons.chevronRight, size: 16, color: t.muted),
                ),
                Divider(height: 1, color: t.border),
                ListTile(
                  leading: Icon(LucideIcons.user, color: t.muted),
                  title: Text('Account', style: t.bodyStyle),
                  trailing: Icon(LucideIcons.chevronRight, size: 16, color: t.muted),
                ),
                Divider(height: 1, color: t.border),
                ListTile(
                  leading: Icon(LucideIcons.logOut, color: t.red),
                  title: Text('Sign Out', style: t.bodyStyle.copyWith(color: t.red)),
                ),
              ]),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
      bottomNavigationBar: AppBottomNav(active: 'profile', onTap: (_) {}),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final AppTokens t;
  const _StatPill({required this.label, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: t.surfaceHi,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Text(label, style: t.miniStyle.copyWith(fontSize: 11)),
    );
  }
}

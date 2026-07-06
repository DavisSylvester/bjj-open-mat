import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/auth/auth_service.dart';
import '../../settings/role_toggle.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/belt_icon.dart';
import '../../../shared/widgets/session_row.dart';
import '../../gyms/data/gym_repository.dart';
import '../data/profile_stats.dart';

final _recentSessions = [
  SessionRowData(gymName: 'Atos HQ', giType: 'gi', expLevel: 'all', time: '7:00 PM', day: 'Mon', distance: '1.2 mi', fee: 0),
  SessionRowData(gymName: 'Renzo Westwood', giType: 'nogi', expLevel: 'int', time: '8:00 PM', day: 'Sat', distance: '2.4 mi', fee: 15),
  SessionRowData(gymName: 'Gracie Barra Pasadena', giType: 'gi', expLevel: 'beg', time: '9:00 AM', day: 'Sun', distance: '4.5 mi', fee: 0),
];

String _memberSince(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  if (d == null) return '—';
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[d.month - 1]} ${d.year}';
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final user = ref.watch(authStateProvider).user;
    final isAdmin = user?.role == 'admin';
    return _GlassProfile(t: t, ref: ref, isAdmin: isAdmin, user: user);
  }
}

class _GlassProfile extends StatelessWidget {
  final AppTokens t;
  final WidgetRef ref;
  final bool isAdmin;
  final UserProfile? user;
  const _GlassProfile({required this.t, required this.ref, required this.isAdmin, required this.user});

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName ?? '';
    final email = user?.email ?? '';
    final beltRank = user?.beltRank ?? 'white';
    final beltStripes = user?.beltStripes ?? 0;
    final avatarUrl = user?.avatarUrl;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final beltBg = t.beltBg[beltRank] ?? t.beltBg['white']!;
    final beltFg = t.beltFg[beltRank] ?? t.beltFg['white']!;
    final beltLabel = beltRank.isNotEmpty ? '${beltRank[0].toUpperCase()}${beltRank.substring(1)}' : 'White';
    final stripeLabel = beltStripes == 1 ? 'stripe' : 'stripes';

    final statsAsync = ref.watch(myStatsProvider);
    final checkInsValue = statsAsync.maybeWhen(data: (s) => '${s.checkIns}', orElse: () => '--');
    final reviewsValue = statsAsync.maybeWhen(data: (s) => '${s.reviews}', orElse: () => '--');
    final gymsValue = statsAsync.maybeWhen(data: (s) => '${s.gyms}', orElse: () => '--');

    final birthday = user?.birthday;
    final age = (birthday != null && birthday.isNotEmpty) ? ageFromBirthday(birthday) : null;
    final ageValue = age != null ? '$age yrs' : (birthday != null && birthday.isNotEmpty ? '—' : 'Add birthday');

    final homeGymId = user?.homeGymId;
    final homeGymValue = (homeGymId != null && homeGymId.isNotEmpty)
        ? ref.watch(gymByIdProvider(homeGymId)).maybeWhen(data: (g) => g.name, orElse: () => '—')
        : 'Set home gym';

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
                    GestureDetector(
                      onTap: () => context.push('/notifications'),
                      child: Stack(
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
                    ),
                    const SizedBox(width: 9),
                    GestureDetector(
                      onTap: () => context.push('/settings'),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(13)),
                        child: Icon(LucideIcons.settings, size: 17, color: t.text),
                      ),
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
                        color: avatarUrl == null || avatarUrl.isEmpty ? beltBg : Colors.white.withValues(alpha: 0.20),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.60), width: 2.5),
                        image: (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                            : null,
                      ),
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Center(child: Text(initial, style: t.h1Style.copyWith(color: beltFg, fontSize: 26)))
                          : null,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName, style: t.h1Style.copyWith(color: Colors.white, fontSize: 23)),
                          const SizedBox(height: 3),
                          Text(email, style: t.bodyStyle.copyWith(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                          const SizedBox(height: 9),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                BeltIcon(rank: beltRank, stripes: beltStripes, size: 22),
                                const SizedBox(width: 6),
                                Text('$beltLabel · $beltStripes $stripeLabel', style: t.miniStyle.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                              ]),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Stat strip — real check-in / review / gym counts
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
                    _MnStatCell(label: 'Check-ins', value: checkInsValue, t: t, borderRight: true),
                    _MnStatCell(label: 'Reviews', value: reviewsValue, t: t, borderRight: true),
                    _MnStatCell(label: 'Gyms', value: gymsValue, t: t, borderRight: false),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Metadata: age, home gym, member since
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
                  _MetaRow(t: t, icon: LucideIcons.cake, label: 'Age', value: ageValue),
                  Divider(height: 1, color: t.border),
                  _MetaRow(t: t, icon: LucideIcons.mapPin, label: 'Home gym', value: homeGymValue),
                  Divider(height: 1, color: t.border),
                  _MetaRow(t: t, icon: LucideIcons.calendarDays, label: 'Member since', value: _memberSince(user?.createdAt)),
                ]),
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
                    leading: Icon(LucideIcons.dumbbell, color: t.muted),
                    title: Text('My Training', style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600, color: t.text)),
                    trailing: Icon(LucideIcons.chevronRight, size: 15, color: t.faint),
                    onTap: () => context.push('/profile/training'),
                  ),
                  Divider(height: 1, color: t.border),
                  ListTile(
                    leading: Icon(LucideIcons.bell, color: t.muted),
                    title: Text('Notifications', style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600, color: t.text)),
                    trailing: Icon(LucideIcons.chevronRight, size: 15, color: t.faint),
                    onTap: () => context.push('/notifications'),
                  ),
                  Divider(height: 1, color: t.border),
                  ListTile(
                    leading: Icon(LucideIcons.user, color: t.muted),
                    title: Text('Account', style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600, color: t.text)),
                    trailing: Icon(LucideIcons.chevronRight, size: 15, color: t.faint),
                    onTap: () => context.push('/profile/edit'),
                  ),
                  Divider(height: 1, color: t.border),
                  Builder(builder: (ctx) {
                    final role = ref.watch(authStateProvider).user?.role;
                    final toggle = roleToggle(role);
                    return ListTile(
                      leading: Icon(LucideIcons.repeat, color: t.muted),
                      title: Text(toggle.label, style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600, color: t.text)),
                      trailing: Icon(LucideIcons.chevronRight, size: 15, color: t.faint),
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        await ref.read(authStateProvider.notifier).setRole(toggle.targetRole);
                        if (ctx.mounted) ctx.go(toggle.destination);
                      },
                    );
                  }),
                  if (isAdmin) ...[
                    Divider(height: 1, color: t.border),
                    ListTile(
                      leading: Icon(LucideIcons.clipboardCheck, color: t.muted),
                      title: Text('Review submissions', style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600, color: t.text)),
                      trailing: Icon(LucideIcons.chevronRight, size: 15, color: t.faint),
                      onTap: () => context.go('/admin/review'),
                    ),
                  ],
                  Divider(height: 1, color: t.border),
                  ListTile(
                    leading: Icon(LucideIcons.logOut, color: t.red),
                    title: Text('Sign out', style: t.bodyStyle.copyWith(color: t.red)),
                    trailing: Icon(LucideIcons.chevronRight, size: 15, color: t.faint),
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await ref.read(authStateProvider.notifier).logout();
                    },
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

class _MetaRow extends StatelessWidget {
  final AppTokens t;
  final IconData icon;
  final String label;
  final String value;
  const _MetaRow({required this.t, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: t.muted),
      title: Text(label, style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600, color: t.text)),
      trailing: Text(value, style: t.bodyStyle.copyWith(color: t.muted)),
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

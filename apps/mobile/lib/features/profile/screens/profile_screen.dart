import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/auth/auth_service.dart';
import '../../settings/role_toggle.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/belt_icon.dart';
import '../../gyms/data/gym_repository.dart';
import '../data/profile_stats.dart';

const _kMonths = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

String _memberSince(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  if (d == null) return '—';
  return '${_kMonths[d.month - 1]} ${d.year}';
}

String? _formatBirthday(String? iso) {
  final d = (iso == null || iso.isEmpty) ? null : DateTime.tryParse(iso);
  if (d == null) return null;
  return '${_kMonths[d.month - 1]} ${d.day}, ${d.year}';
}

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).replaceAll('_', ' ')}';

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

    final homeGymId = user?.homeGymId;
    final homeGymValue = (homeGymId != null && homeGymId.isNotEmpty)
        ? ref.watch(gymByIdProvider(homeGymId)).maybeWhen(data: (g) => g.name, orElse: () => '—')
        : 'Set home gym';

    // Build the metadata rows dynamically so optional fields only appear when set.
    final birthdayLabel = _formatBirthday(birthday);
    final location = [user?.city, user?.state].where((s) => s != null && s.trim().isNotEmpty).join(', ');
    final weightStr = user?.weightValue != null ? '${user!.weightValue!.round()} ${user!.weightUnit ?? 'lb'}' : null;
    final metaRows = <Widget>[];
    void meta(IconData icon, String label, String value) {
      if (metaRows.isNotEmpty) metaRows.add(Divider(height: 1, color: t.border));
      metaRows.add(_MetaRow(t: t, icon: icon, label: label, value: value));
    }
    void metaOpt(IconData icon, String label, String? value) {
      if (value != null && value.trim().isNotEmpty) meta(icon, label, value.trim());
    }
    if (birthdayLabel != null) {
      meta(LucideIcons.cake, 'Birthday', birthdayLabel);
      if (age != null) meta(LucideIcons.gift, 'Age', '$age yrs');
    } else {
      meta(LucideIcons.cake, 'Age', 'Add birthday');
    }
    meta(LucideIcons.mapPin, 'Home gym', homeGymValue);
    metaOpt(LucideIcons.navigation, 'Location', location);
    metaOpt(LucideIcons.dumbbell, 'Weight', weightStr);
    metaOpt(LucideIcons.award, 'Division', user?.weightDivision != null ? _cap(user!.weightDivision!) : null);
    metaOpt(LucideIcons.user, 'Gender', user?.gender != null ? _cap(user!.gender!) : null);
    meta(LucideIcons.calendarDays, 'Member since', _memberSince(user?.createdAt));

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
                    _ProfileAvatar(
                      avatarUrl: avatarUrl,
                      initial: initial,
                      beltBg: beltBg,
                      beltFg: beltFg,
                      style: t.h1Style.copyWith(fontSize: 26),
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
                child: Column(children: metaRows),
              ),
            ),
            const SizedBox(height: 22),
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

class _ProfileAvatar extends StatefulWidget {
  final String? avatarUrl;
  final String initial;
  final Color beltBg;
  final Color beltFg;
  final TextStyle style;
  const _ProfileAvatar({
    required this.avatarUrl,
    required this.initial,
    required this.beltBg,
    required this.beltFg,
    required this.style,
  });

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  bool _failed = false;

  @override
  void didUpdateWidget(covariant _ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      _failed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty && !_failed;
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: hasImage ? Colors.white.withValues(alpha: 0.20) : widget.beltBg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.60), width: 2.5),
        image: hasImage
            ? DecorationImage(
                image: NetworkImage(widget.avatarUrl!),
                fit: BoxFit.cover,
                onError: (_, _) {
                  if (mounted) setState(() => _failed = true);
                },
              )
            : null,
      ),
      child: hasImage
          ? null
          : Center(child: Text(widget.initial, style: widget.style.copyWith(color: widget.beltFg))),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/auth/auth_service.dart';
import '../../settings/role_toggle.dart';
import '../../../core/design/tokens.dart';
import '../data/profile_stats.dart';
import '../widgets/profile_view.dart';

/// Guideline 5.1.1(v): account creation must be paired with an in-app account
/// deletion flow. Confirms intent (irreversible), then deletes the account and
/// all owned data on the backend before signing out locally.
Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref, AppTokens t) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: t.surface,
      title: Text('Delete Account', style: t.h2Style),
      content: Text(
        'This will permanently delete your account and all associated data. This action cannot be undone.',
        style: t.bodyStyle,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text('Delete', style: TextStyle(color: t.red)),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  HapticFeedback.heavyImpact();
  try {
    await ref.read(authStateProvider.notifier).deleteAccount();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete your account. Please try again.')),
      );
    }
    return;
  }
  if (context.mounted) context.go('/login');
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
    final effectiveUser = user ?? const UserProfile(id: '', email: '', displayName: '');

    final statsAsync = ref.watch(myStatsProvider);
    final checkInsValue = statsAsync.maybeWhen(data: (s) => '${s.checkIns}', orElse: () => '--');
    final reviewsValue = statsAsync.maybeWhen(data: (s) => '${s.reviews}', orElse: () => '--');
    final gymsValue = statsAsync.maybeWhen(data: (s) => '${s.gyms}', orElse: () => '--');

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
            profileGlassHero(context, t, effectiveUser),
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
            profileMetaCard(context, ref, t, effectiveUser),
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
                  Divider(height: 1, color: t.border),
                  ListTile(
                    leading: Icon(LucideIcons.trash2, color: t.red),
                    title: Text('Delete Account', style: t.bodyStyle.copyWith(color: t.red)),
                    trailing: Icon(LucideIcons.chevronRight, size: 15, color: t.faint),
                    onTap: () => _confirmDeleteAccount(context, ref, t),
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

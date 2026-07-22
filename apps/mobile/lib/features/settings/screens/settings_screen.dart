import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../core/auth/auth_service.dart';
import '../../../shared/widgets/glass_form.dart';
import '../role_toggle.dart';

/// Back affordance for the full-screen settings route (falls back to /profile
/// if there is nothing to pop).
Widget _settingsBackButton(BuildContext context, AppTokens t) => GestureDetector(
      onTap: () => context.canPop() ? context.pop() : context.go('/profile'),
      child: Icon(LucideIcons.arrowLeft, color: t.text, size: 22),
    );

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

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return _GlassSettings(t: t, ref: ref);
  }
}

class _GlassSettings extends StatelessWidget {
  final AppTokens t;
  final WidgetRef ref;
  const _GlassSettings({required this.t, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(children: [
                _settingsBackButton(context, t),
                const SizedBox(width: 12),
                Text('Settings', style: t.h1Style),
              ]),
            ),
            // PREFERENCES
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Align(alignment: Alignment.centerLeft, child: glassSectionLabel(t, 'Preferences')),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(t.cardRadius),
                border: Border.all(color: t.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(children: [
                ListTile(
                  leading: Icon(LucideIcons.bell, color: t.muted),
                  title: Text('Notifications', style: t.bodyStyle),
                  trailing: Icon(LucideIcons.chevronRight, size: 16, color: t.muted),
                  onTap: () => context.push('/notifications'),
                ),
                Divider(height: 1, color: t.border),
                ListTile(
                  leading: Icon(LucideIcons.shield, color: t.muted),
                  title: Text('Privacy', style: t.bodyStyle),
                  trailing: Icon(LucideIcons.chevronRight, size: 16, color: t.muted),
                  onTap: () {},
                ),
              ]),
            ),
            const SizedBox(height: 20),
            // ACCOUNT
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(alignment: Alignment.centerLeft, child: glassSectionLabel(t, 'Account')),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(t.cardRadius),
                border: Border.all(color: t.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(children: [
                Builder(builder: (ctx) {
                  final role = ref.watch(authStateProvider).user?.role;
                  final toggle = roleToggle(role);
                  return ListTile(
                    leading: Icon(LucideIcons.repeat, color: t.muted),
                    title: Text(toggle.label, style: t.bodyStyle),
                    trailing: Icon(LucideIcons.chevronRight, size: 16, color: t.muted),
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await ref.read(authStateProvider.notifier).setRole(toggle.targetRole);
                      if (ctx.mounted) ctx.go(toggle.destination);
                    },
                  );
                }),
                Divider(height: 1, color: t.border),
                ListTile(
                  leading: Icon(LucideIcons.logOut, color: t.red),
                  title: Text(
                    'Sign Out',
                    style: t.bodyStyle.copyWith(color: t.red),
                  ),
                  onTap: () async {
                    HapticFeedback.heavyImpact();
                    await ref.read(authStateProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
                Divider(height: 1, color: t.border),
                ListTile(
                  leading: Icon(LucideIcons.trash2, color: t.red),
                  title: Text(
                    'Delete Account',
                    style: t.bodyStyle.copyWith(color: t.red),
                  ),
                  onTap: () => _confirmDeleteAccount(context, ref, t),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            // About footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(children: [
                  Icon(LucideIcons.info, color: t.faint, size: 20),
                  const SizedBox(height: 8),
                  Text('BJJ Open Mat Finder', style: t.miniStyle.copyWith(color: t.muted)),
                  const SizedBox(height: 2),
                  Text('v0.1.0', style: t.miniStyle.copyWith(color: t.faint)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

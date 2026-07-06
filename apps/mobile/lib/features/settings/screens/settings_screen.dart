import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../core/auth/auth_service.dart';
import '../role_toggle.dart';

/// Back affordance for the full-screen settings route (falls back to /profile
/// if there is nothing to pop).
Widget _settingsBackButton(BuildContext context, AppTokens t) => GestureDetector(
      onTap: () => context.canPop() ? context.pop() : context.go('/profile'),
      child: Icon(LucideIcons.arrowLeft, color: t.text, size: 22),
    );

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
                Icon(LucideIcons.settings, color: t.muted, size: 20),
                const SizedBox(width: 8),
                Text('Settings', style: t.h1Style),
              ]),
            ),
            // Settings card
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
                Divider(height: 1, color: t.border),
                ListTile(
                  leading: Icon(LucideIcons.info, color: t.muted),
                  title: Text('About', style: t.bodyStyle),
                  subtitle: Text(
                    'BJJ Open Mat Finder v0.1.0',
                    style: t.miniStyle.copyWith(fontSize: 11),
                  ),
                ),
                Divider(height: 1, color: t.border),
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
              ]),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/theme_provider.dart';
import '../../../core/auth/auth_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return t.isSport
        ? _SportSettings(t: t, ref: ref)
        : _GlassSettings(t: t, ref: ref);
  }
}

class _SportSettings extends StatelessWidget {
  final AppTokens t;
  final WidgetRef ref;
  const _SportSettings({required this.t, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          // Masthead
          Container(
            color: t.bg2,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(children: [
              Container(width: 4, height: 28, color: t.red),
              const SizedBox(width: 10),
              Text('Settings', style: t.h1Style.copyWith(fontSize: 22)),
            ]),
          ),
          Divider(height: 1, color: t.border),
          Expanded(
            child: ListView(children: [
              // Theme toggle
              Container(
                color: t.surface,
                child: ListTile(
                  leading: Icon(LucideIcons.palette, color: t.muted, size: 18),
                  title: Text(
                    'Sports Ticker Theme',
                    style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                  trailing: Consumer(
                    builder: (ctx, watchRef, child) => Switch(
                      value: watchRef.watch(themeProvider) == ThemeVariant.sport,
                      activeThumbColor: t.red,
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        watchRef.read(themeProvider.notifier).toggle();
                      },
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: t.border),
              Container(
                color: t.surface,
                child: ListTile(
                  leading: Icon(LucideIcons.bell, color: t.muted, size: 18),
                  title: Text('Notifications', style: t.bodyStyle),
                  trailing: Icon(LucideIcons.chevronRight, size: 16, color: t.faint),
                  onTap: () => context.go('/notifications'),
                ),
              ),
              Divider(height: 1, color: t.border),
              Container(
                color: t.surface,
                child: ListTile(
                  leading: Icon(LucideIcons.shield, color: t.muted, size: 18),
                  title: Text('Privacy', style: t.bodyStyle),
                  trailing: Icon(LucideIcons.chevronRight, size: 16, color: t.faint),
                  onTap: () {},
                ),
              ),
              Divider(height: 1, color: t.border),
              Container(
                color: t.surface,
                child: ListTile(
                  leading: Icon(LucideIcons.info, color: t.muted, size: 18),
                  title: Text('About', style: t.bodyStyle),
                  subtitle: Text(
                    'BJJ Open Mat Finder v0.1.0',
                    style: t.miniStyle.copyWith(fontSize: 10),
                  ),
                  onTap: () {},
                ),
              ),
              Divider(height: 1, color: t.border),
              Container(
                color: t.surface,
                child: ListTile(
                  leading: Icon(LucideIcons.logOut, color: t.red, size: 18),
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
              ),
              Divider(height: 1, color: t.border),
            ]),
          ),
        ]),
      ),
    );
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
                // Theme toggle
                ListTile(
                  leading: Icon(LucideIcons.palette, color: t.muted),
                  title: Text(
                    'Sports Ticker Theme',
                    style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                  trailing: Consumer(
                    builder: (ctx, watchRef, _) => Switch(
                      value: watchRef.watch(themeProvider) == ThemeVariant.sport,
                      activeThumbColor: t.red,
                      onChanged: (_) {
                        HapticFeedback.selectionClick();
                        watchRef.read(themeProvider.notifier).toggle();
                      },
                    ),
                  ),
                ),
                Divider(height: 1, color: t.border),
                ListTile(
                  leading: Icon(LucideIcons.bell, color: t.muted),
                  title: Text('Notifications', style: t.bodyStyle),
                  trailing: Icon(LucideIcons.chevronRight, size: 16, color: t.muted),
                  onTap: () => context.go('/notifications'),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Container(
            color: t.bg2,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.go('/profile'),
                child: Icon(LucideIcons.arrowLeft, size: 20, color: t.text),
              ),
              const SizedBox(width: 12),
              if (t.isSport)
                Container(width: 4, height: 22, color: t.red, margin: const EdgeInsets.only(right: 8)),
              Expanded(child: Text('Owner Panel', style: t.h1Style.copyWith(fontSize: 20))),
              Icon(LucideIcons.bell, size: 18, color: t.muted),
            ]),
          ),
          if (t.isSport) Divider(height: 1, color: t.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Stat row
                Row(children: [
                  _StatCard(t: t, icon: LucideIcons.store, label: 'My Gyms', value: '--', accent: t.gi,
                      onTap: () => context.go('/owner/gyms')),
                  const SizedBox(width: 10),
                  _StatCard(t: t, icon: LucideIcons.calendar, label: 'Sessions', value: '--', accent: t.red,
                      onTap: () => context.go('/owner/sessions')),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _StatCard(t: t, icon: LucideIcons.users, label: 'Check-ins', value: '--', accent: t.green,
                      onTap: () {}),
                  const SizedBox(width: 10),
                  _StatCard(t: t, icon: LucideIcons.star, label: 'Avg Rating', value: '--', accent: t.amber,
                      onTap: () {}),
                ]),
                const SizedBox(height: 20),
                // Section header
                Row(children: [
                  if (t.isSport) Container(width: 4, height: 16, color: t.red, margin: const EdgeInsets.only(right: 8)),
                  Text('Quick Actions', style: t.h2Style.copyWith(fontSize: 14)),
                ]),
                const SizedBox(height: 10),
                _ActionRow(t: t,
                  icon: LucideIcons.plusSquare,
                  accent: t.gi,
                  label: 'Add New Gym',
                  sub: 'Register a gym location',
                  onTap: () => context.go('/owner/gyms/add'),
                ),
                const SizedBox(height: 8),
                _ActionRow(t: t,
                  icon: LucideIcons.calendarPlus,
                  accent: t.red,
                  label: 'Create Open Mat',
                  sub: 'Schedule a new session',
                  onTap: () => context.go('/owner/sessions/create'),
                ),
                const SizedBox(height: 8),
                _ActionRow(t: t,
                  icon: LucideIcons.clipboardList,
                  accent: t.amber,
                  label: 'Manage Sessions',
                  sub: 'View and edit all sessions',
                  onTap: () => context.go('/owner/sessions'),
                ),
                const SizedBox(height: 8),
                _ActionRow(t: t,
                  icon: LucideIcons.building2,
                  accent: t.both,
                  label: 'My Gyms',
                  sub: 'View and manage your gyms',
                  onTap: () => context.go('/owner/gyms'),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final AppTokens t;
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final VoidCallback onTap;

  const _StatCard({required this.t, required this.icon, required this.label, required this.value, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(t.cardRadius),
            border: Border.all(color: t.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: accent),
            const SizedBox(height: 8),
            Text(value, style: t.h1Style.copyWith(fontSize: 26, color: accent)),
            Text(label, style: t.miniStyle),
          ]),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final AppTokens t;
  final IconData icon;
  final Color accent;
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _ActionRow({required this.t, required this.icon, required this.accent, required this.label, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: t.isSport
              ? Border(left: BorderSide(color: accent, width: 3))
              : Border.all(color: t.border),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(t.badgeRadius),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600)),
            Text(sub, style: t.miniStyle.copyWith(color: t.muted)),
          ])),
          Icon(LucideIcons.chevronRight, size: 16, color: t.muted),
        ]),
      ),
    );
  }
}

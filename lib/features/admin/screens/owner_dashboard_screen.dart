import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/glass_card.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [IconButton(icon: const Icon(Icons.notifications), onPressed: () => context.go('/notifications'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(StitchTokens.md),
        children: [
          // Stats row
          Row(children: [
            _DashCard(icon: Icons.store, label: 'My Gyms', value: '--', color: StitchTokens.secondary, onTap: () => context.go('/owner/gyms')),
            const SizedBox(width: StitchTokens.sm),
            _DashCard(icon: Icons.event, label: 'Sessions', value: '--', color: StitchTokens.accent, onTap: () => context.go('/owner/sessions')),
          ]),
          const SizedBox(height: StitchTokens.sm),
          Row(children: [
            _DashCard(icon: Icons.people, label: 'Check-ins', value: '--', color: StitchTokens.warning, onTap: () {}),
            const SizedBox(width: StitchTokens.sm),
            _DashCard(icon: Icons.star, label: 'Avg Rating', value: '--', color: Colors.amber, onTap: () {}),
          ]),
          const SizedBox(height: StitchTokens.lg),

          // Quick actions
          Text('Quick Actions', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: StitchTokens.sm),
          ListTile(
            leading: const Icon(Icons.add_business, color: StitchTokens.secondary),
            title: const Text('Add New Gym'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/owner/gyms/add'),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle, color: StitchTokens.accent),
            title: const Text('Create Open Mat'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/owner/sessions/create'),
          ),
        ],
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  const _DashCard({required this.icon, required this.label, required this.value, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineLarge),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

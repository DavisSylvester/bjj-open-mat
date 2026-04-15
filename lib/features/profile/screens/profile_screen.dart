import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/auth/auth_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () => context.go('/settings')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(StitchTokens.md),
        children: [
          // Avatar + name
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: BeltColors.fromRank(user.beltRank ?? 'white'),
                  child: Text(
                    user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                const SizedBox(height: StitchTokens.md),
                Text(user.displayName, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: BeltColors.fromRank(user.beltRank ?? 'white').withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(StitchTokens.radiusPill),
                  ),
                  child: Text(
                    '${(user.beltRank ?? "white")[0].toUpperCase()}${(user.beltRank ?? "white").substring(1)} Belt',
                    style: TextStyle(color: BeltColors.fromRank(user.beltRank ?? 'white'), fontWeight: FontWeight.w600),
                  ),
                ),
                if (user.bio != null) ...[
                  const SizedBox(height: StitchTokens.sm),
                  Text(user.bio!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
          const SizedBox(height: StitchTokens.xl),

          // Actions
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () { HapticFeedback.selectionClick(); context.go('/profile/edit'); },
          ),
          ListTile(
            leading: const Icon(Icons.favorite, color: StitchTokens.secondary),
            title: const Text('Favorite Gyms'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () { HapticFeedback.selectionClick(); context.go('/profile/favorites'); },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () { HapticFeedback.selectionClick(); context.go('/notifications'); },
          ),

          // Owner mode — show if user is gym_owner
          if (user.isGymOwner) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: StitchTokens.warning),
              title: const Text('Gym Owner Dashboard'),
              subtitle: const Text('Manage gyms, sessions, attendance'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () { HapticFeedback.mediumImpact(); context.go('/owner/dashboard'); },
            ),
            ListTile(
              leading: const Icon(Icons.store, color: StitchTokens.secondary),
              title: const Text('My Gyms'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () { HapticFeedback.selectionClick(); context.go('/owner/gyms'); },
            ),
            ListTile(
              leading: const Icon(Icons.event, color: StitchTokens.accent),
              title: const Text('Manage Sessions'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () { HapticFeedback.selectionClick(); context.go('/owner/sessions'); },
            ),
          ],

          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: StitchTokens.error),
            title: const Text('Log Out', style: TextStyle(color: StitchTokens.error)),
            onTap: () async {
              HapticFeedback.heavyImpact();
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

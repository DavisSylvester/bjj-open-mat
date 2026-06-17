import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/glass_card.dart';

class RoleSelectScreen extends ConsumerWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: StitchTokens.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(StitchTokens.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: StitchTokens.xxl),
              Text(
                'Welcome!',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: StitchTokens.sm),
              Text(
                'How will you use the app?',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: StitchTokens.textSecondary),
              ),
              const SizedBox(height: StitchTokens.xxl),

              _RoleCard(
                icon: Icons.sports_martial_arts,
                title: 'Practitioner',
                description: 'Find open mats, check in, track training, leave reviews',
                color: StitchTokens.accent,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.go('/profile-setup');
                },
              ),
              const SizedBox(height: StitchTokens.md),
              _RoleCard(
                icon: Icons.store,
                title: 'Gym Owner',
                description: 'Register gyms, post schedules, track attendance',
                color: StitchTokens.secondary,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.go('/profile-setup');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(StitchTokens.lg),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(StitchTokens.radiusMd),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: StitchTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(color: StitchTokens.textSecondary, fontSize: 14)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white54),
        ],
      ),
    );
  }
}

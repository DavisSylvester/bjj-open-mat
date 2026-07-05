import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/auth/auth_service.dart';
import '../../../shared/widgets/glass_card.dart';

class RoleSelectScreen extends ConsumerWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: OMSpacing.lg),
            // The content + footer form one group, centered with balanced margins
            // so the footer hint stays anchored just below the cards (no dead void).
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),

                // Brand mark ties back to the splash screen.
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: OMColors.crimson.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(StitchTokens.radiusLg),
                  ),
                  child: const Icon(Icons.sports_martial_arts, color: OMColors.crimson, size: 30),
                ),
                const SizedBox(height: OMSpacing.lg),

                Text(
                  'GET STARTED',
                  style: text.labelSmall?.copyWith(
                    color: OMColors.crimsonDeep,
                    letterSpacing: 0.18,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: OMSpacing.xs),
                Text(
                  'Welcome!',
                  style: text.headlineLarge?.copyWith(color: OMColors.text),
                ),
                const SizedBox(height: OMSpacing.sm),
                Text(
                  'How will you use the app? Pick a role to set up your experience.',
                  style: text.bodyLarge?.copyWith(color: OMColors.body, height: 1.35),
                ),

                const SizedBox(height: OMSpacing.xl),

                _RoleCard(
                  icon: Icons.sports_martial_arts,
                  title: 'Practitioner',
                  description: 'Find open mats near you, check in, track training, and leave reviews.',
                  accent: OMColors.teal,
                  accentDeep: OMColors.tealDeep,
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await ref.read(authStateProvider.notifier).setRole('practitioner');
                    if (context.mounted) context.go('/profile-setup');
                  },
                ),
                const SizedBox(height: OMSpacing.md),
                _RoleCard(
                  icon: Icons.fitness_center_rounded,
                  title: 'Gym Owner',
                  description: 'Register your gym, post open-mat schedules, and track attendance.',
                  accent: OMColors.crimson,
                  accentDeep: OMColors.crimsonDeep,
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await ref.read(authStateProvider.notifier).setRole('gym_owner');
                    if (context.mounted) context.go('/owner/dashboard');
                  },
                ),

                const SizedBox(height: OMSpacing.xl),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 16, color: OMColors.body),
                      const SizedBox(width: OMSpacing.xs),
                      Text(
                        'You can switch roles anytime in Settings',
                        style: text.bodySmall?.copyWith(color: OMColors.body),
                      ),
                    ],
                  ),
                ),

                const Spacer(),
              ],
            ),
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
  final Color accent;
  final Color accentDeep;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.accentDeep,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return GlassCard(
      onTap: onTap,
      elevated: true,
      borderRadius: StitchTokens.radiusXl,
      padding: const EdgeInsets.all(OMSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(StitchTokens.radiusLg),
              border: Border.all(color: accent.withValues(alpha: 0.32)),
            ),
            child: Icon(icon, color: accentDeep, size: 28),
          ),
          const SizedBox(width: OMSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleMedium?.copyWith(
                    color: OMColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: OMSpacing.xs),
                Text(
                  description,
                  style: text.bodyMedium?.copyWith(color: OMColors.body, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: OMSpacing.sm),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_forward_ios_rounded, color: accentDeep, size: 15),
          ),
        ],
      ),
    );
  }
}

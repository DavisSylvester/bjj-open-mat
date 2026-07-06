import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../core/auth/auth_service.dart';
import '../../../shared/widgets/belt_pin.dart';

class RoleSelectScreen extends ConsumerWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),

              // Brand mark — matches the app's indigo→violet avatar gradient.
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [t.primary, t.both],
                  ),
                  boxShadow: [
                    BoxShadow(color: t.primary.withValues(alpha: 0.27), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: const Center(child: BeltPin.onColor(size: 34)),
              ),
              const SizedBox(height: 22),

              Text(
                'GET STARTED',
                style: t.miniStyle.copyWith(color: t.primary, fontSize: 12, letterSpacing: 0.14),
              ),
              const SizedBox(height: 6),
              Text('Welcome!', style: t.h1Style.copyWith(fontSize: 34)),
              const SizedBox(height: 8),
              Text(
                'How will you use the app? Pick a role to set up your experience.',
                style: t.bodyStyle.copyWith(color: t.body, fontSize: 15, height: 1.4),
              ),

              const SizedBox(height: 28),

              _RoleCard(
                t: t,
                icon: LucideIcons.user,
                title: 'Practitioner',
                description: 'Find open mats near you, check in, track training, and leave reviews.',
                accent: t.primary,
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await ref.read(authStateProvider.notifier).setRole('practitioner');
                  if (context.mounted) context.go('/profile-setup');
                },
              ),
              const SizedBox(height: 14),
              _RoleCard(
                t: t,
                icon: LucideIcons.building2,
                title: 'Gym Owner',
                description: 'Register your gym, post open-mat schedules, and track attendance.',
                accent: t.gold,
                accentGlyph: const Color(0xFF9A6200), // deep amber for WCAG contrast on the light gold tile
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await ref.read(authStateProvider.notifier).setRole('gym_owner');
                  if (context.mounted) context.go('/owner/dashboard');
                },
              ),

              const SizedBox(height: 28),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.repeat, size: 15, color: t.muted),
                    const SizedBox(width: 6),
                    Text(
                      'You can switch roles anytime in Settings',
                      style: t.miniStyle.copyWith(color: t.muted, fontSize: 12, letterSpacing: 0),
                    ),
                  ],
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final AppTokens t;
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final Color? accentGlyph;
  final VoidCallback onTap;

  const _RoleCard({
    required this.t,
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    this.accentGlyph,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glyph = accentGlyph ?? accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: t.border),
          boxShadow: const [
            BoxShadow(color: Color(0x0F14151A), blurRadius: 20, offset: Offset(0, 10)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: glyph, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.h2Style.copyWith(fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: t.bodyStyle.copyWith(color: t.body, fontSize: 13.5, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.chevronRight, color: glyph, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

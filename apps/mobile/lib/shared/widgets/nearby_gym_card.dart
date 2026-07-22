import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/design/tokens.dart';
import '../../features/gyms/models/gym.dart';
import '../../features/gyms/data/directions.dart';
import '../../features/gyms/data/website_links.dart';

/// A glass-styled card for a gym within range: name, distance, rating, a
/// tappable address (opens directions) and website (opens the browser). The
/// card body taps through to the gym detail screen.
class NearbyGymCard extends ConsumerWidget {
  final Gym gym;

  const NearbyGymCard({super.key, required this.gym});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final address = gym.address.trim();
    final website = gym.website?.trim() ?? '';

    return GestureDetector(
      onTap: () => context.push('/gym/${gym.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1)),
            BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: t.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(LucideIcons.mapPin, size: 17, color: t.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(gym.name, style: t.h2Style.copyWith(fontSize: 16), overflow: TextOverflow.ellipsis),
                      ),
                      if (gym.distanceKm != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: t.primary.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${(gym.distanceKm! / 1.60934).round()} mi',
                            style: t.miniStyle.copyWith(fontSize: 11, color: t.primary, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                      if (gym.rating != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: t.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.star, size: 11, color: t.gold),
                              const SizedBox(width: 3),
                              Text(
                                gym.rating!.toStringAsFixed(1),
                                style: t.miniStyle.copyWith(fontSize: 11, color: t.gold, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      key: const Key('nearby-gym-address'),
                      onTap: () => openDirections(ref, context, gymId: gym.id, address: address),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.mapPin, size: 14, color: t.muted),
                          const SizedBox(width: 6),
                          Expanded(child: Text(address, style: t.miniStyle.copyWith(color: t.body, fontSize: 12))),
                          const SizedBox(width: 6),
                          Icon(LucideIcons.navigation, size: 15, color: t.primary),
                        ],
                      ),
                    ),
                  ],
                  if (website.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      key: const Key('nearby-gym-website'),
                      onTap: () => openWebsite(context, website),
                      child: Row(
                        children: [
                          Icon(LucideIcons.globe, size: 14, color: t.muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              websiteDisplayHost(website),
                              style: t.miniStyle.copyWith(color: t.primary, fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/design/tokens.dart';
import '../../features/open_mats/models/open_mat.dart';

/// Presentational summary of a gym with its soonest upcoming open mat, used to
/// fill the "Gyms near you" section when a feed has too few results to be
/// visually satisfying on its own.
class GymSummary {
  final String gymId;
  final String name;
  final String? city;
  final String? state;
  final double? rating;
  final String nextDay;
  final String nextTime;

  const GymSummary({
    required this.gymId,
    required this.name,
    this.city,
    this.state,
    this.rating,
    required this.nextDay,
    required this.nextTime,
  });

  String? get locationLabel {
    if (city != null && city!.isNotEmpty && state != null && state!.isNotEmpty) {
      return '$city, $state';
    }
    return (city?.isNotEmpty ?? false) ? city : (state?.isNotEmpty ?? false ? state : null);
  }
}

/// Groups a list of [OpenMat]s by `gymId`, one summary per distinct gym, using
/// each gym's soonest-upcoming session for the displayed day/time/rating.
/// Gyms with an empty [OpenMat.gymId] are skipped.
List<GymSummary> distinctGymsFromOpenMats(List<OpenMat> mats) {
  final byGym = <String, List<OpenMat>>{};
  for (final mat in mats) {
    if (mat.gymId.isEmpty) continue;
    byGym.putIfAbsent(mat.gymId, () => []).add(mat);
  }

  final summaries = <GymSummary>[];
  for (final entry in byGym.entries) {
    final group = entry.value
      ..sort((a, b) {
        final dateCompare = a.nextSessionDate().compareTo(b.nextSessionDate());
        if (dateCompare != 0) return dateCompare;
        return a.startTime.compareTo(b.startTime);
      });
    final soonest = group.first;
    summaries.add(GymSummary(
      gymId: entry.key,
      name: soonest.gymName ?? soonest.title,
      city: soonest.city,
      state: soonest.state,
      rating: soonest.gymRating,
      nextDay: soonest.dayName,
      nextTime: soonest.startLabel,
    ));
  }
  return summaries;
}

/// A compact glass-styled card for a nearby gym: name, city/state, an
/// optional rating pill, and its next open-mat day/time. Taps navigate to the
/// gym detail screen.
class GymCard extends StatelessWidget {
  final GymSummary gym;
  final VoidCallback? onTap;

  const GymCard({super.key, required this.gym, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return GestureDetector(
      onTap: onTap ?? () => context.go('/gym/${gym.gymId}'),
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
                        child: Text(
                          gym.name,
                          style: t.h2Style.copyWith(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
                  if (gym.locationLabel != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      gym.locationLabel!,
                      style: t.miniStyle.copyWith(color: t.muted, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(LucideIcons.clock, size: 12, color: t.muted),
                      const SizedBox(width: 5),
                      Text(
                        'Next: ${gym.nextDay} ${gym.nextTime}',
                        style: t.bodyStyle.copyWith(color: t.body, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

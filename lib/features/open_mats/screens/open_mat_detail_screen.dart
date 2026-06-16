import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/auth/auth_service.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/glass_card.dart';
import '../models/open_mat.dart';
import '../../gyms/models/gym.dart';

final openMatDetailProvider = FutureProvider.family<OpenMat, String>((ref, id) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get(Endpoints.openMatById(id));
  return OpenMat.fromJson(response.data['data'] as Map<String, dynamic>);
});

final hostProfileProvider = FutureProvider.family<UserProfile?, String>((ref, hostId) async {
  if (hostId.isEmpty) return null;
  final api = ref.read(apiClientProvider);
  try {
    final response = await api.get(Endpoints.userById(hostId));
    return UserProfile.fromJson(response.data['data'] as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

final gymForOpenMatProvider = FutureProvider.family<Gym?, String>((ref, gymId) async {
  if (gymId.isEmpty) return null;
  final api = ref.read(apiClientProvider);
  try {
    final response = await api.get(Endpoints.gymById(gymId));
    return Gym.fromJson(response.data['data'] as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

class OpenMatDetailScreen extends ConsumerWidget {
  final String openMatId;
  const OpenMatDetailScreen({super.key, required this.openMatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matAsync = ref.watch(openMatDetailProvider(openMatId));

    return Scaffold(
      body: matAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(openMatDetailProvider(openMatId))),
        data: (mat) => _OpenMatContent(mat: mat, openMatId: openMatId),
      ),
      bottomNavigationBar: matAsync.whenOrNull(
        data: (mat) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(StitchTokens.md),
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('Check In'),
                style: ElevatedButton.styleFrom(backgroundColor: StitchTokens.accent, foregroundColor: Colors.white),
                onPressed: mat.isCancelled ? null : () async {
                  HapticFeedback.heavyImpact();
                  final api = ref.read(apiClientProvider);
                  try {
                    await api.post(Endpoints.openMatCheckin(openMatId), data: {'openMatId': openMatId, 'status': 'checked_in'});
                    if (context.mounted) context.go('/open-mat/$openMatId/checkin-success');
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Check-in failed: $e')));
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OpenMatContent extends ConsumerWidget {
  final OpenMat mat;
  final String openMatId;
  const _OpenMatContent({required this.mat, required this.openMatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymAsync = ref.watch(gymForOpenMatProvider(mat.gymId));
    final hostAsync = ref.watch(hostProfileProvider(mat.hostId ?? ''));

    return CustomScrollView(
      slivers: [
        // Hero header — gym image background with gym name + instructor
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(mat.title, style: const TextStyle(fontSize: 16, shadows: [Shadow(blurRadius: 8, color: Colors.black54)])),
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Gym image — use gym photo URL or fallback gradient
                gymAsync.whenOrNull(
                  data: (gym) {
                    // If gym has images, use the first one; otherwise gradient
                    return Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        image: gym != null && gym.amenities.isNotEmpty
                            ? null // Would use DecorationImage with CachedNetworkImageProvider
                            : null,
                      ),
                    );
                  },
                ) ?? Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // Dark overlay for text readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),

                // Gym name + instructor overlay
                Positioned(
                  bottom: 60,
                  left: StitchTokens.md,
                  right: StitchTokens.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Gym name
                      gymAsync.whenOrNull(
                        data: (gym) => gym != null
                            ? Row(
                                children: [
                                  const Icon(Icons.store, color: Colors.white70, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    gym.name,
                                    style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                  if (gym.isVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, color: StitchTokens.accent, size: 14),
                                  ],
                                ],
                              )
                            : const SizedBox.shrink(),
                      ) ?? const SizedBox.shrink(),

                      const SizedBox(height: 8),

                      // Instructor chip
                      hostAsync.whenOrNull(
                        data: (host) => host != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(StitchTokens.radiusPill),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: BeltColors.fromRank(host.beltRank ?? 'white'),
                                      child: Text(
                                        host.displayName.isNotEmpty ? host.displayName[0].toUpperCase() : '?',
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Host: ${host.displayName}',
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          '${(host.beltRank ?? "white")[0].toUpperCase()}${(host.beltRank ?? "white").substring(1)} Belt',
                                          style: const TextStyle(color: Colors.white60, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ) ?? const SizedBox.shrink(),
                    ],
                  ),
                ),

                // Session type badge (top right)
                Positioned(
                  top: 80,
                  right: StitchTokens.md,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: mat.isGiSession ? StitchTokens.secondary : StitchTokens.accent,
                      borderRadius: BorderRadius.circular(StitchTokens.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          mat.isGiSession ? Icons.checkroom : Icons.sports_martial_arts,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          mat.isGiSession ? 'Gi' : 'No-Gi',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.all(StitchTokens.md),
          sliver: SliverList(delegate: SliverChildListDelegate([

            // Badges row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Badge(mat.skillBadge, StitchTokens.accent),
                _Badge(mat.giBadge, StitchTokens.secondary),
                if (mat.isRecurring) _Badge('Recurring', StitchTokens.warning),
                if (mat.isCancelled) _Badge('Cancelled', StitchTokens.error),
              ],
            ),
            const SizedBox(height: StitchTokens.lg),

            // Schedule card
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule, color: StitchTokens.accent, size: 20),
                      const SizedBox(width: 8),
                      Text('Schedule', style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: StitchTokens.sm),
                  Text(
                    '${mat.dayName} ${mat.startTime} – ${mat.endTime}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (mat.specificDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(mat.specificDate!, style: Theme.of(context).textTheme.bodySmall),
                    ),
                ],
              ),
            ),
            const SizedBox(height: StitchTokens.md),

            // Participants
            if (mat.maxParticipants != null && mat.maxParticipants! > 0) ...[
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people, color: StitchTokens.secondary, size: 20),
                        const SizedBox(width: 8),
                        Text('Participants', style: Theme.of(context).textTheme.titleLarge),
                        const Spacer(),
                        Text('${mat.checkinCount ?? 0} / ${mat.maxParticipants}', style: Theme.of(context).textTheme.headlineMedium),
                      ],
                    ),
                    const SizedBox(height: StitchTokens.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (mat.checkinCount ?? 0) / mat.maxParticipants!,
                        minHeight: 8,
                        color: StitchTokens.accent,
                        backgroundColor: StitchTokens.accent.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: StitchTokens.md),
            ],

            // Description
            if (mat.description != null && mat.description!.isNotEmpty) ...[
              Text('About', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: StitchTokens.sm),
              Text(mat.description!, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: StitchTokens.lg),
            ],

            // === GYM DETAILS SECTION ===
            Text('Gym', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: StitchTokens.sm),

            gymAsync.when(
              loading: () => const Card(child: Padding(padding: EdgeInsets.all(StitchTokens.lg), child: Center(child: CircularProgressIndicator()))),
              error: (e, _) => const Card(child: Padding(padding: EdgeInsets.all(StitchTokens.md), child: Text('Could not load gym details'))),
              data: (gym) {
                if (gym == null) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.store, color: StitchTokens.secondary),
                      title: Text(mat.gymName ?? 'Unknown Gym'),
                      subtitle: const Text('Tap to view gym'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/gym/${mat.gymId}'),
                    ),
                  );
                }

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(StitchTokens.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Gym name + verified badge
                        Row(
                          children: [
                            const Icon(Icons.store, color: StitchTokens.secondary, size: 24),
                            const SizedBox(width: StitchTokens.sm),
                            Expanded(
                              child: Text(gym.name, style: Theme.of(context).textTheme.titleLarge),
                            ),
                            if (gym.isVerified)
                              const Icon(Icons.verified, color: StitchTokens.accent, size: 20),
                          ],
                        ),

                        if (gym.description != null) ...[
                          const SizedBox(height: StitchTokens.sm),
                          Text(gym.description!, style: Theme.of(context).textTheme.bodySmall),
                        ],

                        const Divider(height: StitchTokens.lg),

                        // Address — clickable for directions
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (gym.location != null) {
                              launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${gym.location!.lat},${gym.location!.lng}'));
                            }
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.location_on, color: StitchTokens.secondary, size: 20),
                              const SizedBox(width: StitchTokens.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(gym.address, style: Theme.of(context).textTheme.bodyLarge),
                                    Text('Tap for directions', style: TextStyle(color: StitchTokens.accent, fontSize: 12, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.directions, color: StitchTokens.accent),
                            ],
                          ),
                        ),

                        // Phone — clickable to call
                        if (gym.phone != null) ...[
                          const SizedBox(height: StitchTokens.md),
                          InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              launchUrl(Uri.parse('tel:${gym.phone}'));
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.phone, color: StitchTokens.accent, size: 20),
                                const SizedBox(width: StitchTokens.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(gym.phone!, style: Theme.of(context).textTheme.bodyLarge),
                                      Text('Tap to call', style: TextStyle(color: StitchTokens.accent, fontSize: 12, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.call, color: StitchTokens.accent),
                              ],
                            ),
                          ),
                        ],

                        // Website — clickable
                        if (gym.website != null) ...[
                          const SizedBox(height: StitchTokens.md),
                          InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              launchUrl(Uri.parse(gym.website!));
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.language, color: StitchTokens.accent, size: 20),
                                const SizedBox(width: StitchTokens.sm),
                                Expanded(
                                  child: Text(gym.website!, style: TextStyle(color: StitchTokens.accent, fontSize: 14, decoration: TextDecoration.underline)),
                                ),
                                const Icon(Icons.open_in_new, color: StitchTokens.accent, size: 16),
                              ],
                            ),
                          ),
                        ],

                        // Amenities
                        if (gym.amenities.isNotEmpty) ...[
                          const SizedBox(height: StitchTokens.md),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: gym.amenities.map((a) => Chip(
                              label: Text(a.replaceAll('_', ' '), style: const TextStyle(fontSize: 12)),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: StitchTokens.accent.withValues(alpha: 0.1),
                            )).toList(),
                          ),
                        ],

                        const SizedBox(height: StitchTokens.md),

                        // Directions buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.directions, size: 18),
                                label: const Text('Google Maps'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: StitchTokens.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  if (gym.location != null) {
                                    launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${gym.location!.lat},${gym.location!.lng}'));
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: StitchTokens.sm),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.navigation, size: 18),
                                label: const Text('Waze'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  if (gym.location != null) {
                                    launchUrl(Uri.parse('https://waze.com/ul?ll=${gym.location!.lat},${gym.location!.lng}&navigate=yes'));
                                  }
                                },
                              ),
                            ),
                          ],
                        ),

                        // View full gym page
                        const SizedBox(height: StitchTokens.sm),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => context.go('/gym/${gym.id}'),
                            child: const Text('View Full Gym Profile →'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: StitchTokens.xxl),
          ])),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(StitchTokens.radiusPill)),
      child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

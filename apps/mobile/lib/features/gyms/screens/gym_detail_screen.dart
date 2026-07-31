import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../../../shared/widgets/error_state.dart';
import '../../favorites/data/favorite_repository.dart';
import '../../gym_claims/widgets/gym_claim_entry.dart';
import '../../membership/widgets/join_gym_button.dart';
import '../data/gym_permissions.dart';
import '../data/gym_repository.dart';
import '../data/directions.dart';
import '../data/logo_banner_dismissal.dart';
import '../models/gym.dart';

class GymDetailScreen extends ConsumerWidget {
  final String? gymId;
  const GymDetailScreen({super.key, this.gymId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<AppTokens>()!;
    final id = gymId;
    if (id == null || id.isEmpty) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(backgroundColor: t.bg, foregroundColor: t.text, elevation: 0),
        body: const ErrorState(message: 'Gym not found'),
      );
    }
    final async = ref.watch(gymByIdProvider(id));
    return async.when(
      loading: () => Scaffold(backgroundColor: t.bg, body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(backgroundColor: t.bg, foregroundColor: t.text, elevation: 0),
        body: ErrorState(message: "Couldn't load gym", onRetry: () => ref.invalidate(gymByIdProvider(id))),
      ),
      data: (gym) => _GlassGymDetail(t: t, gym: gym),
    );
  }
}

class _GlassGymDetail extends ConsumerWidget {
  final AppTokens t;
  final Gym gym;
  const _GlassGymDetail({required this.t, required this.gym});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(myFavoritesProvider);
    final canManage = deriveCanManageGym(ref, gymId: gym.id, ownerId: gym.ownerId);
    final canAccessForum = deriveCanAccessForumGym(ref, gymId: gym.id, ownerId: gym.ownerId);
    final isFavorite = favoritesAsync.maybeWhen(
      data: (gyms) => gyms.any((g) => g.id == gym.id),
      orElse: () => false,
    );
    final location = [gym.city, gym.state].where((s) => s != null && s.isNotEmpty).join(', ');

    return Scaffold(
      backgroundColor: t.bg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: t.bg2,
          leading: GestureDetector(
            onTap: () => context.canPop() ? context.pop() : context.go('/'),
            child: Icon(LucideIcons.arrowLeft, color: t.text),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () async {
                  final repo = ref.read(favoriteRepositoryProvider);
                  try {
                    if (isFavorite) {
                      await repo.remove(gym.id);
                    } else {
                      await repo.add(gym.id);
                    }
                    ref.invalidate(myFavoritesProvider);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Couldn't update favorite")),
                      );
                    }
                  }
                },
                child: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? t.red : Colors.white,
                ),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [t.primary, t.both],
                  ),
                ),
              ),
              Positioned(bottom: 16, left: 16, right: 16, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(gym.name.toUpperCase(), style: t.h1Style.copyWith(fontSize: 28, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(location.isEmpty ? gym.address : location, style: t.bodyStyle.copyWith(color: Colors.white70)),
                ],
              )),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(delegate: SliverChildListDelegate([
            Row(children: [
              if (gym.rating != null) ...[
                _Pill(label: '${gym.rating!.toStringAsFixed(1)} ★', color: t.amber, t: t),
                const SizedBox(width: 8),
              ],
              if (gym.isVerified) _Pill(label: 'Verified', color: t.green, t: t),
            ]),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => openDirections(ref, context, gymId: gym.id, address: gym.address),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: t.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(LucideIcons.navigation, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Directions', style: t.miniStyle.copyWith(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            JoinGymButton(gymId: gym.id),
            GymClaimEntry(gymId: gym.id, ownerId: gym.ownerId),
            ref.watch(logoBannerDismissedProvider(gym.id)).when(
              loading: () => const SizedBox.shrink(),
              error: (err, _) => const SizedBox.shrink(),
              data: (dismissed) {
                final show = shouldShowLogoBanner(
                  logoUrl: gym.logoUrl,
                  isGymOwner: ref.watch(authStateProvider).user?.isGymOwner ?? false,
                  ownsThisGym: gym.ownerId != null && gym.ownerId == ref.watch(currentUserIdProvider),
                  dismissed: dismissed,
                );
                if (!show) return const SizedBox.shrink();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      key: const Key('gym-logo-banner'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: t.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Add your gym's logo",
                                    style: t.labelStyle.copyWith(fontWeight: FontWeight.w700, color: t.text)),
                                const SizedBox(height: 4),
                                Text('Gyms with a logo stand out in search and on open mats.',
                                    style: t.miniStyle.copyWith(color: t.muted)),
                              ],
                            ),
                          ),
                          TextButton(
                            key: const Key('gym-logo-banner-add'),
                            onPressed: () => context.push('/owner/gyms/${gym.id}'),
                            child: const Text('Add'),
                          ),
                          IconButton(
                            key: const Key('gym-logo-banner-dismiss'),
                            icon: Icon(Icons.close, size: 18, color: t.muted),
                            onPressed: () async {
                              await dismissLogoBanner(gym.id);
                              ref.invalidate(logoBannerDismissedProvider(gym.id));
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.push('/gym/${gym.id}/open-mats'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.border),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.event_available_outlined, size: 16, color: t.text),
                  const SizedBox(width: 8),
                  Text('Open Mats', style: t.miniStyle.copyWith(color: t.text, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.push('/gym/${gym.id}/roster'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.border),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.people_outline, size: 16, color: t.text),
                  const SizedBox(width: 8),
                  Text('Members', style: t.miniStyle.copyWith(color: t.text, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.push('/gym/${gym.id}/schedule'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.border),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.calendar_month_outlined, size: 16, color: t.text),
                  const SizedBox(width: 8),
                  Text('Class schedule', style: t.miniStyle.copyWith(color: t.text, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            if (canAccessForum) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => context.push('/gym/${gym.id}/forum'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.forum_outlined, size: 16, color: t.text),
                    const SizedBox(width: 8),
                    Text('Forum', style: t.miniStyle.copyWith(color: t.text, fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ],
            if (canAccessForum) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => context.push('/gym/${gym.id}/channels'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.tag, size: 16, color: t.text),
                    const SizedBox(width: 8),
                    Text('Channels', style: t.miniStyle.copyWith(color: t.text, fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ],
            if (canManage) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => context.push('/gym/${gym.id}/instructor-feedback'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(LucideIcons.messageSquare, size: 16, color: t.text),
                    const SizedBox(width: 8),
                    Text('Instructor feedback', style: t.miniStyle.copyWith(color: t.text, fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => context.push('/gym/${gym.id}/message-reports'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(LucideIcons.flag, size: 16, color: t.text),
                    const SizedBox(width: 8),
                    Text('Message reports', style: t.miniStyle.copyWith(color: t.text, fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ],
            if (gym.description != null && gym.description!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('About', style: t.h2Style),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(t.cardRadius),
                  border: Border.all(color: t.border),
                  boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Text(gym.description!, style: t.bodyStyle),
              ),
            ],
            const SizedBox(height: 80),
          ])),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final AppTokens t;
  const _Pill({required this.label, required this.color, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.33)),
      ),
      child: Text(label, style: t.miniStyle.copyWith(color: color, fontSize: 11)),
    );
  }
}

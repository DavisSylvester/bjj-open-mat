import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../shared/widgets/error_state.dart';
import '../models/gym.dart';

final gymDetailProvider = FutureProvider.family<Gym, String>((ref, id) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get(Endpoints.gymById(id));
  return Gym.fromJson(response.data['data'] as Map<String, dynamic>);
});

class _GymFavoritesNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => {};
  void set(String id, {required bool value}) => state = {...state, id: value};
}

final gymFavoritesProvider = NotifierProvider<_GymFavoritesNotifier, Map<String, bool>>(_GymFavoritesNotifier.new);

class GymDetailScreen extends ConsumerWidget {
  final String gymId;
  const GymDetailScreen({super.key, required this.gymId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymAsync = ref.watch(gymDetailProvider(gymId));
    final isFavorite = ref.watch(gymFavoritesProvider.select((m) => m[gymId] ?? false));

    return Scaffold(
      body: gymAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(gymDetailProvider(gymId))),
        data: (gym) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(gym.name),
                background: Container(
                  color: StitchTokens.primary,
                  child: const Center(child: Icon(Icons.store, size: 64, color: Colors.white24)),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: StitchTokens.secondary),
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final api = ref.read(apiClientProvider);
                    if (isFavorite) {
                      await api.delete(Endpoints.gymFavorite(gymId));
                    } else {
                      await api.post(Endpoints.gymFavorite(gymId));
                    }
                    ref.read(gymFavoritesProvider.notifier).set(gymId, value: !isFavorite);
                  },
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(StitchTokens.md),
              sliver: SliverList(delegate: SliverChildListDelegate([
                // Address
                ListTile(
                  leading: const Icon(Icons.location_on, color: StitchTokens.secondary),
                  title: Text(gym.address),
                  subtitle: Text([gym.city, gym.state, gym.country].where((s) => s != null).join(', ')),
                ),

                // Contact
                if (gym.phone != null) ListTile(leading: const Icon(Icons.phone), title: Text(gym.phone!), onTap: () => launchUrl(Uri.parse('tel:${gym.phone}'))),
                if (gym.website != null) ListTile(leading: const Icon(Icons.language), title: Text(gym.website!), onTap: () => launchUrl(Uri.parse(gym.website!))),

                // Amenities
                if (gym.amenities.isNotEmpty) ...[
                  const SizedBox(height: StitchTokens.md),
                  Text('Amenities', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: StitchTokens.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: gym.amenities.map((a) => Chip(label: Text(a), visualDensity: VisualDensity.compact)).toList(),
                  ),
                ],

                // Directions button
                const SizedBox(height: StitchTokens.lg),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.directions),
                        label: const Text('Google Maps'),
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
                        icon: const Icon(Icons.navigation),
                        label: const Text('Waze'),
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
              ])),
            ),
          ],
        ),
      ),
    );
  }
}

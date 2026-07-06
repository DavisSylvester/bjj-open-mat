import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../gyms/data/gym_repository.dart';
import '../../gyms/models/gym.dart';

final myGymsProvider = FutureProvider<List<Gym>>((ref) async {
  return ref.read(gymRepositoryProvider).listMine();
});

class MyGymsScreen extends ConsumerWidget {
  const MyGymsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymsAsync = ref.watch(myGymsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Gyms')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myGymsProvider),
        child: gymsAsync.when(
          loading: () => const ShimmerList(),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(myGymsProvider)),
          data: (gyms) {
            if (gyms.isEmpty) return const EmptyState(title: 'No gyms yet', subtitle: 'Register your first gym', icon: Icons.store);
            return ListView.builder(
              padding: const EdgeInsets.all(StitchTokens.md),
              itemCount: gyms.length,
              itemBuilder: (context, i) {
                final gym = gyms[i];
                return Card(
                  child: ListTile(
                    leading: _GymLogo(logoUrl: gym.logoUrl),
                    title: Text(gym.name),
                    subtitle: Text(gym.address),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () { HapticFeedback.selectionClick(); context.go('/owner/gyms/${gym.id}'); },
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: StitchTokens.secondary,
        onPressed: () => context.go('/owner/gyms/add'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

/// Gym logo thumbnail for list rows: shows the uploaded logo when present,
/// otherwise a neutral store placeholder.
class _GymLogo extends StatelessWidget {
  final String? logoUrl;
  const _GymLogo({this.logoUrl});

  @override
  Widget build(BuildContext context) {
    final placeholder = CircleAvatar(
      backgroundColor: StitchTokens.secondary.withValues(alpha: 0.15),
      child: const Icon(Icons.store, color: StitchTokens.secondary),
    );
    if (logoUrl == null || logoUrl!.isEmpty) return placeholder;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: logoUrl!,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}

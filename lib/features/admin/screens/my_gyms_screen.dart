import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../gyms/models/gym.dart';

final myGymsProvider = FutureProvider<List<Gym>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get(Endpoints.gyms);
  final raw = response.data['data'];
  final List data = raw is List ? raw : (raw is Map ? (raw['items'] as List? ?? []) : []);
  return data.map((e) => Gym.fromJson(e as Map<String, dynamic>)).toList();
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
                    leading: CircleAvatar(backgroundColor: StitchTokens.secondary.withValues(alpha: 0.15), child: const Icon(Icons.store, color: StitchTokens.secondary)),
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

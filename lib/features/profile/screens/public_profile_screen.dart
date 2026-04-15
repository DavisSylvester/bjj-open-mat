import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/auth/auth_service.dart';
import '../../../shared/widgets/error_state.dart';

final publicProfileProvider = FutureProvider.family<UserProfile, String>((ref, userId) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get(Endpoints.userById(userId));
  return UserProfile.fromJson(response.data['data'] as Map<String, dynamic>);
});

class PublicProfileScreen extends ConsumerWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(publicProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (user) => Center(
          child: Padding(
            padding: const EdgeInsets.all(StitchTokens.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: BeltColors.fromRank(user.beltRank ?? 'white'),
                  child: Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(height: StitchTokens.md),
                Text(user.displayName, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: StitchTokens.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: BeltColors.fromRank(user.beltRank ?? 'white').withValues(alpha: 0.2), borderRadius: BorderRadius.circular(StitchTokens.radiusPill)),
                  child: Text('${(user.beltRank ?? "white")[0].toUpperCase()}${(user.beltRank ?? "white").substring(1)} Belt', style: TextStyle(color: BeltColors.fromRank(user.beltRank ?? 'white'), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

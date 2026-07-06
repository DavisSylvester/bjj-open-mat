import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../widgets/profile_view.dart';

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
    final t = Theme.of(context).extension<AppTokens>()!;
    final profileAsync = ref.watch(publicProfileProvider(userId));

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(LucideIcons.arrowLeft, color: t.text),
                  ),
                ),
              ),
              profileAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) {
                  final isNotFound = e is DioException && e.response?.statusCode == 404;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isNotFound ? "This profile isn't available." : "Couldn't load this profile.",
                            style: t.h1Style.copyWith(fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isNotFound
                                ? 'The attendee you\'re looking for may have moved or removed their profile.'
                                : 'Please check your connection and try again.',
                            style: t.bodyStyle.copyWith(color: t.muted),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => ref.invalidate(publicProfileProvider(userId)),
                            style: TextButton.styleFrom(foregroundColor: t.primary),
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                data: (user) => Column(
                  children: [
                    profileGlassHero(context, t, user),
                    const SizedBox(height: 14),
                    profileMetaCard(context, ref, t, user, editable: false),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

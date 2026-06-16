import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../open_mats/models/open_mat.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';

class _SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

final searchQueryProvider = NotifierProvider<_SearchQueryNotifier, String>(_SearchQueryNotifier.new);

class _SearchFiltersNotifier extends Notifier<SearchFilters> {
  @override
  SearchFilters build() => const SearchFilters();
  void set(SearchFilters value) => state = value;
}

final searchFiltersProvider = NotifierProvider<_SearchFiltersNotifier, SearchFilters>(_SearchFiltersNotifier.new);

final searchResultsProvider = FutureProvider<List<OpenMat>>((ref) async {
  final filters = ref.watch(searchFiltersProvider);
  final api = ref.read(apiClientProvider);
  final params = <String, dynamic>{};
  if (filters.dayOfWeek != null) params['dayOfWeek'] = filters.dayOfWeek;
  if (filters.skillLevel != null) params['skillLevel'] = filters.skillLevel;
  if (filters.isGi != null) params['isGiSession'] = filters.isGi;
  params['page'] = 1;
  params['limit'] = 20;

  final response = await api.get(Endpoints.openMats, queryParameters: params);
  final data = response.data['data'];
  final List items = data is List ? data : (data is Map ? (data['items'] as List? ?? []) : []);
  return items.map((e) => OpenMat.fromJson(e as Map<String, dynamic>)).toList();
});

class SearchFilters {
  final int? dayOfWeek;
  final String? skillLevel;
  final bool? isGi;
  const SearchFilters({this.dayOfWeek, this.skillLevel, this.isGi});

  SearchFilters copyWith({int? dayOfWeek, String? skillLevel, bool? isGi}) =>
      SearchFilters(dayOfWeek: dayOfWeek ?? this.dayOfWeek, skillLevel: skillLevel ?? this.skillLevel, isGi: isGi ?? this.isGi);
}

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchResultsProvider);
    final filters = ref.watch(searchFiltersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Open Mats'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: StitchTokens.md, vertical: StitchTokens.sm),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(label: 'All Levels', selected: filters.skillLevel == null, onTap: () => ref.read(searchFiltersProvider.notifier).set(filters.copyWith(skillLevel: null))),
                  _FilterChip(label: 'Beginner', selected: filters.skillLevel == 'beginner', onTap: () => ref.read(searchFiltersProvider.notifier).set(SearchFilters(skillLevel: 'beginner', isGi: filters.isGi))),
                  _FilterChip(label: 'Intermediate', selected: filters.skillLevel == 'intermediate', onTap: () => ref.read(searchFiltersProvider.notifier).set(SearchFilters(skillLevel: 'intermediate', isGi: filters.isGi))),
                  _FilterChip(label: 'Advanced', selected: filters.skillLevel == 'advanced', onTap: () => ref.read(searchFiltersProvider.notifier).set(SearchFilters(skillLevel: 'advanced', isGi: filters.isGi))),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Gi', selected: filters.isGi == true, onTap: () => ref.read(searchFiltersProvider.notifier).set(filters.copyWith(isGi: true))),
                  _FilterChip(label: 'No-Gi', selected: filters.isGi == false, onTap: () => ref.read(searchFiltersProvider.notifier).set(filters.copyWith(isGi: false))),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(searchResultsProvider),
        child: resultsAsync.when(
          loading: () => const ShimmerList(itemCount: 8),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(searchResultsProvider)),
          data: (mats) {
            if (mats.isEmpty) return const EmptyState(title: 'No results', icon: Icons.search_off);
            return ListView.builder(
              padding: const EdgeInsets.all(StitchTokens.md),
              itemCount: mats.length,
              itemBuilder: (context, i) {
                final mat = mats[i];
                return ListTile(
                  leading: CircleAvatar(backgroundColor: StitchTokens.accent.withValues(alpha: 0.15), child: const Icon(Icons.sports_martial_arts, color: StitchTokens.accent)),
                  title: Text(mat.title),
                  subtitle: Text('${mat.gymName ?? ""} • ${mat.dayName} ${mat.startTime}'),
                  trailing: Text(mat.skillBadge, style: TextStyle(color: StitchTokens.accent, fontSize: 12)),
                  onTap: () { HapticFeedback.selectionClick(); context.go('/open-mat/${mat.id}'); },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(label: Text(label), selected: selected, onSelected: (_) { HapticFeedback.selectionClick(); onTap(); }),
    );
  }
}

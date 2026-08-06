import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/gym.dart';
import 'gym_search_query.dart';
import 'gym_search_repository.dart';

class GymSearchState {
  final List<Gym> items;
  final int total;

  /// The radius that produced [items]. May exceed the requested radius when the
  /// API auto-widened a search that would otherwise have been empty.
  final double effectiveRadiusKm;

  /// The radius the user actually asked for. When this differs from
  /// [effectiveRadiusKm] the UI shows a widened-search notice.
  final double requestedRadiusKm;

  final bool loading;
  final Object? error;

  /// True once a search has been submitted — distinguishes "no results" from
  /// "nothing searched yet", which need different empty states.
  final bool searched;

  const GymSearchState({
    this.items = const <Gym>[],
    this.total = 0,
    this.effectiveRadiusKm = 0,
    this.requestedRadiusKm = 0,
    this.loading = false,
    this.error,
    this.searched = false,
  });

  bool get hasMore => items.length < total;
  bool get widened => searched && effectiveRadiusKm > requestedRadiusKm;

  GymSearchState copyWith({
    List<Gym>? items,
    int? total,
    double? effectiveRadiusKm,
    double? requestedRadiusKm,
    bool? loading,
    Object? error,
    bool clearError = false,
    bool? searched,
  }) =>
      GymSearchState(
        items: items ?? this.items,
        total: total ?? this.total,
        effectiveRadiusKm: effectiveRadiusKm ?? this.effectiveRadiusKm,
        requestedRadiusKm: requestedRadiusKm ?? this.requestedRadiusKm,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        searched: searched ?? this.searched,
      );
}

/// Accumulates pages of gym search results.
///
/// A Notifier rather than a FutureProvider because paging needs to append to a
/// list that survives across fetches; a FutureProvider replaces its value on
/// every request.
///
/// Requests race: `submit` will be wired to a debounced text field and a radius
/// slider, so overlapping `submit`/`loadMore` calls are expected, not exotic.
/// [_generation] guards against a stale request's response landing after a
/// newer one already reset or advanced the state — every submit/loadMore bumps
/// it, captures its own value locally, and discards its result (writes nothing
/// to `state`, touches nothing on `_query`) if that value is no longer current
/// by the time the awaited call resolves.
class GymSearchController extends Notifier<GymSearchState> {
  GymSearchQuery? _query;
  int _generation = 0;

  @override
  GymSearchState build() => const GymSearchState();

  /// Run a new search. Resets to page 1 and discards accumulated results.
  Future<void> submit(GymSearchQuery query) async {
    final generation = ++_generation;

    if (!query.hasOrigin) {
      state = const GymSearchState(searched: true);
      return;
    }

    final first = query.copyWith(page: 1);
    _query = first;
    state = state.copyWith(
      items: const <Gym>[],
      total: 0,
      loading: true,
      clearError: true,
      requestedRadiusKm: first.radiusKm,
      effectiveRadiusKm: first.radiusKm,
      searched: true,
    );

    try {
      final page = await ref.read(gymSearchRepositoryProvider).search(first);
      if (generation != _generation) return; // superseded by a newer submit/loadMore
      // Page subsequent requests at the radius that produced page 1, so the
      // user scrolls through one stable result set rather than a shifting one.
      _query = first.copyWith(radiusKm: page.effectiveRadiusKm);
      state = state.copyWith(
        items: page.items,
        total: page.total,
        effectiveRadiusKm: page.effectiveRadiusKm,
        loading: false,
      );
    } catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  /// Append the next page. No-op while loading, when everything is already
  /// loaded, or before the first search.
  Future<void> loadMore() async {
    final current = _query;
    if (current == null || state.loading || !state.hasMore) return;

    final generation = ++_generation;
    final next = current.copyWith(page: current.page + 1);
    state = state.copyWith(loading: true, clearError: true);

    try {
      final page = await ref.read(gymSearchRepositoryProvider).search(next);
      if (generation != _generation) return; // superseded by a newer submit/loadMore
      _query = next;
      state = state.copyWith(
        items: <Gym>[...state.items, ...page.items],
        total: page.total,
        loading: false,
      );
    } catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(loading: false, error: e);
    }
  }
}

final gymSearchControllerProvider =
    NotifierProvider<GymSearchController, GymSearchState>(GymSearchController.new);

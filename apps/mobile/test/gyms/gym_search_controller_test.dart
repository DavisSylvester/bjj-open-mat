import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bjj_open_mat/features/gyms/models/gym.dart';
import 'package:bjj_open_mat/features/gyms/models/gym_search_page.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_search_query.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_search_repository.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_search_controller.dart';

/// Returns one gym per page, reporting a total of 3, so paging is observable.
class _FakeRepo implements GymSearchRepository {
  final List<GymSearchQuery> calls = <GymSearchQuery>[];
  final double effectiveRadiusKm;
  _FakeRepo({this.effectiveRadiusKm = 40});

  @override
  Future<GymSearchPage> search(GymSearchQuery query) async {
    calls.add(query);
    return GymSearchPage(
      items: [Gym(id: 'g-${query.page}', name: 'Gym ${query.page}', address: 'A')],
      total: 3,
      effectiveRadiusKm: effectiveRadiusKm,
    );
  }
}

/// Hands back one uncompleted future per call, in call order, so a test can
/// resolve them out of order to simulate a race.
class _ControllableRepo implements GymSearchRepository {
  final List<GymSearchQuery> calls = <GymSearchQuery>[];
  final List<Completer<GymSearchPage>> completers = <Completer<GymSearchPage>>[];

  @override
  Future<GymSearchPage> search(GymSearchQuery query) {
    calls.add(query);
    final c = Completer<GymSearchPage>();
    completers.add(c);
    return c.future;
  }
}

/// Succeeds on its first call (page 1), then throws on every call after that.
class _FailsAfterFirstPageRepo implements GymSearchRepository {
  final List<GymSearchQuery> calls = <GymSearchQuery>[];

  @override
  Future<GymSearchPage> search(GymSearchQuery query) async {
    calls.add(query);
    if (calls.length == 1) {
      return GymSearchPage(
        items: [Gym(id: 'g-1', name: 'Gym 1', address: 'A')],
        total: 3,
        effectiveRadiusKm: 40,
      );
    }
    throw Exception('network error');
  }
}

ProviderContainer _containerWith(GymSearchRepository repo) => ProviderContainer(
      overrides: [gymSearchRepositoryProvider.overrideWithValue(repo)],
    );

void main() {
  test('submit loads page 1 and reports hasMore', () async {
    final repo = _FakeRepo();
    final c = _containerWith(repo);
    addTearDown(c.dispose);

    await c.read(gymSearchControllerProvider.notifier)
        .submit(const GymSearchQuery(lat: 1, lng: 2, radiusKm: 40));

    final s = c.read(gymSearchControllerProvider);
    expect(s.items.map((g) => g.id), ['g-1']);
    expect(s.total, 3);
    expect(s.hasMore, isTrue);
    expect(s.loading, isFalse);
  });

  test('loadMore appends rather than replacing', () async {
    final repo = _FakeRepo();
    final c = _containerWith(repo);
    addTearDown(c.dispose);
    final notifier = c.read(gymSearchControllerProvider.notifier);

    await notifier.submit(const GymSearchQuery(lat: 1, lng: 2, radiusKm: 40));
    await notifier.loadMore();

    expect(c.read(gymSearchControllerProvider).items.map((g) => g.id), ['g-1', 'g-2']);
    expect(repo.calls.map((q) => q.page), [1, 2]);
  });

  test('loadMore pages at the effective radius, not the requested one', () async {
    final repo = _FakeRepo(effectiveRadiusKm: 80);
    final c = _containerWith(repo);
    addTearDown(c.dispose);
    final notifier = c.read(gymSearchControllerProvider.notifier);

    await notifier.submit(const GymSearchQuery(lat: 1, lng: 2, radiusKm: 40));
    await notifier.loadMore();

    expect(repo.calls[1].radiusKm, 80);
  });

  test('submit resets accumulated items', () async {
    final repo = _FakeRepo();
    final c = _containerWith(repo);
    addTearDown(c.dispose);
    final notifier = c.read(gymSearchControllerProvider.notifier);

    await notifier.submit(const GymSearchQuery(lat: 1, lng: 2, radiusKm: 40));
    await notifier.loadMore();
    await notifier.submit(const GymSearchQuery(lat: 1, lng: 2, q: 'atos', radiusKm: 40));

    expect(c.read(gymSearchControllerProvider).items.map((g) => g.id), ['g-1']);
  });

  test('loadMore is a no-op once every item is loaded', () async {
    final repo = _FakeRepo();
    final c = _containerWith(repo);
    addTearDown(c.dispose);
    final notifier = c.read(gymSearchControllerProvider.notifier);

    await notifier.submit(const GymSearchQuery(lat: 1, lng: 2, radiusKm: 40));
    await notifier.loadMore();
    await notifier.loadMore();   // now 3 of 3
    await notifier.loadMore();   // must not fire a 4th request

    expect(repo.calls.map((q) => q.page), [1, 2, 3]);
  });

  test('submit with no origin does not call the API', () async {
    final repo = _FakeRepo();
    final c = _containerWith(repo);
    addTearDown(c.dispose);

    await c.read(gymSearchControllerProvider.notifier)
        .submit(const GymSearchQuery(radiusKm: 40));

    expect(repo.calls, isEmpty);
    expect(c.read(gymSearchControllerProvider).items, isEmpty);
  });

  test('a stale submit resolving after a newer one does not overwrite it', () async {
    final repo = _ControllableRepo();
    final c = _containerWith(repo);
    addTearDown(c.dispose);
    final notifier = c.read(gymSearchControllerProvider.notifier);

    final firstCall = notifier.submit(const GymSearchQuery(q: 'first', lat: 1, lng: 2, radiusKm: 40));
    final secondCall = notifier.submit(const GymSearchQuery(q: 'second', lat: 1, lng: 2, radiusKm: 40));

    expect(repo.completers.length, 2);

    // The second (newer) request resolves first.
    repo.completers[1].complete(GymSearchPage(
      items: [Gym(id: 'second', name: 'Second', address: 'A')],
      total: 1,
      effectiveRadiusKm: 40,
    ));
    await secondCall;

    // The first (stale) request resolves last — it must be discarded.
    repo.completers[0].complete(GymSearchPage(
      items: [Gym(id: 'first', name: 'First', address: 'A')],
      total: 1,
      effectiveRadiusKm: 40,
    ));
    await firstCall;

    final state = c.read(gymSearchControllerProvider);
    expect(state.items.map((g) => g.id), ['second']);
  });

  test('submit firing while a loadMore is in flight discards the stale page', () async {
    final repo = _ControllableRepo();
    final c = _containerWith(repo);
    addTearDown(c.dispose);
    final notifier = c.read(gymSearchControllerProvider.notifier);

    // Page 1 of the first query completes normally.
    final firstSubmit = notifier.submit(const GymSearchQuery(q: 'first', lat: 1, lng: 2, radiusKm: 40));
    repo.completers[0].complete(GymSearchPage(
      items: [Gym(id: 'first-1', name: 'First 1', address: 'A')],
      total: 3,
      effectiveRadiusKm: 40,
    ));
    await firstSubmit;

    // loadMore starts (page 2 of the first query) but does not resolve yet.
    final loadMoreCall = notifier.loadMore();
    expect(repo.completers.length, 2);

    // A new submit fires while that loadMore is still in flight.
    final secondSubmit = notifier.submit(const GymSearchQuery(q: 'second', lat: 1, lng: 2, radiusKm: 40));
    repo.completers[2].complete(GymSearchPage(
      items: [Gym(id: 'second-1', name: 'Second 1', address: 'A')],
      total: 1,
      effectiveRadiusKm: 40,
    ));
    await secondSubmit;

    // The stale loadMore now resolves — it must not be appended onto the new query's list.
    repo.completers[1].complete(GymSearchPage(
      items: [Gym(id: 'first-2', name: 'First 2', address: 'A')],
      total: 3,
      effectiveRadiusKm: 40,
    ));
    await loadMoreCall;

    final state = c.read(gymSearchControllerProvider);
    expect(state.items.map((g) => g.id), ['second-1']);
  });

  test('a failed loadMore preserves the already-accumulated items', () async {
    final repo = _FailsAfterFirstPageRepo();
    final c = _containerWith(repo);
    addTearDown(c.dispose);
    final notifier = c.read(gymSearchControllerProvider.notifier);

    await notifier.submit(const GymSearchQuery(lat: 1, lng: 2, radiusKm: 40));
    await notifier.loadMore();

    final state = c.read(gymSearchControllerProvider);
    expect(state.items.map((g) => g.id), ['g-1']);
    expect(state.loading, isFalse);
    expect(state.error, isNotNull);
  });

  test('loadMore before any submit is a no-op', () async {
    final repo = _FakeRepo();
    final c = _containerWith(repo);
    addTearDown(c.dispose);

    await c.read(gymSearchControllerProvider.notifier).loadMore();

    expect(repo.calls, isEmpty);
    expect(c.read(gymSearchControllerProvider).items, isEmpty);
  });
}

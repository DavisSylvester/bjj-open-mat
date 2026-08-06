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

ProviderContainer _containerWith(_FakeRepo repo) => ProviderContainer(
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
}

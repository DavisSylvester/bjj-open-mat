import 'package:bjj_open_mat/core/api/api_client.dart';
import 'package:bjj_open_mat/core/location/geo_repository.dart';
import 'package:bjj_open_mat/core/location/location_controller.dart';
import 'package:bjj_open_mat/core/location/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLocationService implements LocationService {
  _FakeLocationService({this.returnNull = false});

  final bool returnNull;
  int calls = 0;

  @override
  Future<CapturedLocation?> current() async {
    calls++;
    if (returnNull) return null;
    return const CapturedLocation(latitude: 33.4, longitude: -96.5);
  }
}

class _FakeGeo extends GeoRepository {
  _FakeGeo() : super(ApiClient());

  @override
  Future<ReverseGeocode?> reverse(double lat, double lng) async =>
      const ReverseGeocode(city: 'Frisco', state: 'TX', label: 'Frisco, TX');
}

void main() {
  test('ensure() fetches once and caches', () async {
    final loc = _FakeLocationService();
    final container = ProviderContainer(overrides: [
      locationServiceProvider.overrideWithValue(loc),
      geoRepositoryProvider.overrideWithValue(_FakeGeo()),
    ]);
    addTearDown(container.dispose);

    await container.read(locationControllerProvider.notifier).ensure();
    await container.read(locationControllerProvider.notifier).ensure();

    final state = container.read(locationControllerProvider);
    expect(state.status, LocationStatus.ready);
    expect(state.hasCoords, isTrue);
    expect(state.label, 'Frisco, TX');
    expect(loc.calls, 1);
  });

  test('ensure() with no fix -> unavailable', () async {
    final loc = _FakeLocationService(returnNull: true);
    final container = ProviderContainer(overrides: [
      locationServiceProvider.overrideWithValue(loc),
      geoRepositoryProvider.overrideWithValue(_FakeGeo()),
    ]);
    addTearDown(container.dispose);

    await container.read(locationControllerProvider.notifier).ensure();

    final state = container.read(locationControllerProvider);
    expect(state.status, LocationStatus.unavailable);
    expect(state.hasCoords, isFalse);
  });

  test('refresh() re-fetches even when ready', () async {
    final loc = _FakeLocationService();
    final container = ProviderContainer(overrides: [
      locationServiceProvider.overrideWithValue(loc),
      geoRepositoryProvider.overrideWithValue(_FakeGeo()),
    ]);
    addTearDown(container.dispose);

    await container.read(locationControllerProvider.notifier).ensure();
    await container.read(locationControllerProvider.notifier).refresh();

    expect(loc.calls, 2);
  });

  test('concurrent ensure() calls share one in-flight fetch and both see coords', () async {
    final loc = _FakeLocationService();
    final container = ProviderContainer(overrides: [
      locationServiceProvider.overrideWithValue(loc),
      geoRepositoryProvider.overrideWithValue(_FakeGeo()),
    ]);
    addTearDown(container.dispose);

    // Simulates Home + Find both calling ensure() before the first resolves.
    final notifier = container.read(locationControllerProvider.notifier);
    await Future.wait([notifier.ensure(), notifier.ensure()]);

    final state = container.read(locationControllerProvider);
    expect(loc.calls, 1); // joined, not duplicated
    expect(state.status, LocationStatus.ready);
    expect(state.hasCoords, isTrue);
    expect(state.label, 'Frisco, TX');
  });
}

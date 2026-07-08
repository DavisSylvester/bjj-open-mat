import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'geo_repository.dart';
import 'location_service.dart';

enum LocationStatus { idle, loading, ready, unavailable }

class LocationState {
  final LocationStatus status;
  final double? lat;
  final double? lng;
  final String? label;
  const LocationState({this.status = LocationStatus.idle, this.lat, this.lng, this.label});
  bool get hasCoords => lat != null && lng != null;
  LocationState copyWith({LocationStatus? status, double? lat, double? lng, String? label}) =>
      LocationState(status: status ?? this.status, lat: lat ?? this.lat, lng: lng ?? this.lng, label: label ?? this.label);
}

class LocationController extends Notifier<LocationState> {
  // Tracks an in-flight fetch so concurrent callers (Home + Find) share the
  // same capture and can await its completion instead of racing a half-done
  // state — awaiting ensure()/refresh() always resolves to the final state.
  Future<void>? _inflight;

  @override
  LocationState build() => const LocationState();

  /// Fetch coords once. Reuses (and awaits) an in-flight fetch; a completed
  /// `ready` state is a fast no-op.
  Future<void> ensure() {
    if (state.status == LocationStatus.ready) return Future<void>.value();
    return _inflight ??= _fetch();
  }

  /// Force a fresh capture (GPS chip / map-pin tap). Joins an in-flight fetch
  /// rather than starting a duplicate.
  Future<void> refresh() => _inflight ??= _fetch();

  Future<void> _fetch() async {
    state = state.copyWith(status: LocationStatus.loading);
    try {
      final loc = await ref.read(locationServiceProvider).current();
      if (loc == null) {
        state = const LocationState(status: LocationStatus.unavailable);
        return;
      }
      state = LocationState(status: LocationStatus.ready, lat: loc.latitude, lng: loc.longitude);
      final rg = await ref.read(geoRepositoryProvider).reverse(loc.latitude, loc.longitude);
      if (rg != null) state = state.copyWith(label: rg.label);
    } finally {
      _inflight = null;
    }
  }
}

final locationControllerProvider =
    NotifierProvider<LocationController, LocationState>(LocationController.new);

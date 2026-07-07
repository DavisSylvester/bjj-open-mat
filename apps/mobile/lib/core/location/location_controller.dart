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
  @override
  LocationState build() => const LocationState();

  /// Fetch coords once. No-op if already loading or already resolved (ready).
  Future<void> ensure() async {
    if (state.status == LocationStatus.loading || state.status == LocationStatus.ready) return;
    await _fetch();
  }

  /// Force a fresh capture (GPS chip / map-pin tap). No-op while a fetch is in flight.
  Future<void> refresh() async {
    if (state.status == LocationStatus.loading) return;
    await _fetch();
  }

  Future<void> _fetch() async {
    state = state.copyWith(status: LocationStatus.loading);
    final loc = await ref.read(locationServiceProvider).current();
    if (loc == null) {
      state = const LocationState(status: LocationStatus.unavailable);
      return;
    }
    state = LocationState(status: LocationStatus.ready, lat: loc.latitude, lng: loc.longitude);
    final rg = await ref.read(geoRepositoryProvider).reverse(loc.latitude, loc.longitude);
    if (rg != null) state = state.copyWith(label: rg.label);
  }
}

final locationControllerProvider =
    NotifierProvider<LocationController, LocationState>(LocationController.new);

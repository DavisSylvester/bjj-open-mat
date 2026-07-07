import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class CapturedLocation {
  final double latitude;
  final double longitude;
  final double? accuracyM;
  const CapturedLocation({required this.latitude, required this.longitude, this.accuracyM});
}

abstract class LocationService {
  /// Returns the current location, or null if permission is denied / location is
  /// off / it times out. Never throws.
  Future<CapturedLocation?> current();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<CapturedLocation?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _lastKnown();
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      try {
        // Medium accuracy resolves a city-level fix fast enough for "near me"
        // search; high accuracy often stalls indoors / on a cold GPS chip.
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)),
        );
        return CapturedLocation(latitude: pos.latitude, longitude: pos.longitude, accuracyM: pos.accuracy);
      } catch (_) {
        // Fresh fix timed out — fall back to the last cached fix so the search
        // still resolves to roughly where you are instead of doing nothing.
        return _lastKnown();
      }
    } catch (_) {
      return null;
    }
  }

  Future<CapturedLocation?> _lastKnown() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null) return null;
      return CapturedLocation(latitude: pos.latitude, longitude: pos.longitude, accuracyM: pos.accuracy);
    } catch (_) {
      return null;
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => GeolocatorLocationService());

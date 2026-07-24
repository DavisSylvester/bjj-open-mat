import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// True when a GPS fix is a plausible real-world location. Emulators and cold
/// GPS chips frequently report (0,0) (Null Island) or out-of-range/non-finite
/// values; those must NOT be treated as "near me" or the near-you query
/// matches nothing and discovery looks empty. Returning false here routes the
/// app into the location-less browse-all path.
bool isPlausibleFix(double lat, double lng) {
  if (!lat.isFinite || !lng.isFinite) return false;
  if (lat.abs() > 90 || lng.abs() > 180) return false;
  if (lat.abs() < 0.01 && lng.abs() < 0.01) return false; // Null Island
  return true;
}

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
        if (!isPlausibleFix(pos.latitude, pos.longitude)) return _lastKnown();
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
      if (pos == null || !isPlausibleFix(pos.latitude, pos.longitude)) return null;
      return CapturedLocation(latitude: pos.latitude, longitude: pos.longitude, accuracyM: pos.accuracy);
    } catch (_) {
      return null;
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => GeolocatorLocationService());

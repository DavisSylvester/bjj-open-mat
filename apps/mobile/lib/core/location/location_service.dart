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
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
      return CapturedLocation(latitude: pos.latitude, longitude: pos.longitude, accuracyM: pos.accuracy);
    } catch (_) {
      return null;
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => GeolocatorLocationService());

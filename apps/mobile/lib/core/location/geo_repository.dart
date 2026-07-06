import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/endpoints.dart';

class ReverseGeocode {
  final String city;
  final String state;
  final String label;
  const ReverseGeocode({required this.city, required this.state, required this.label});

  factory ReverseGeocode.fromJson(Map<String, dynamic> json) => ReverseGeocode(
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
        label: json['label'] as String? ?? '',
      );
}

class GeoRepository {
  final ApiClient _api;
  GeoRepository(this._api);

  /// Returns a "City, ST" label for the given coordinates, or null on failure.
  Future<ReverseGeocode?> reverse(double lat, double lng) async {
    try {
      final res = await _api.get(Endpoints.geoReverse, queryParameters: {'lat': lat, 'lng': lng});
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      final rg = ReverseGeocode.fromJson(data);
      return rg.label.isEmpty ? null : rg;
    } catch (_) {
      return null;
    }
  }

  /// Returns a "City, ST" label for a 5-digit ZIP code, or null on failure.
  Future<ReverseGeocode?> zip(String zip) async {
    try {
      final res = await _api.get(Endpoints.geoZip, queryParameters: {'zip': zip});
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      final rg = ReverseGeocode.fromJson(data);
      return rg.label.isEmpty ? null : rg;
    } catch (_) {
      return null;
    }
  }
}

final geoRepositoryProvider = Provider<GeoRepository>((ref) => GeoRepository(ref.read(apiClientProvider)));

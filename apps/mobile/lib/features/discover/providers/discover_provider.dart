import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../open_mats/models/open_mat.dart';
import '../../gyms/models/gym.dart';

final nearbyOpenMatsProvider = FutureProvider.family<List<OpenMat>, NearbyQuery>((ref, query) async {
  final api = ref.read(apiClientProvider);
  // Use list endpoint — nearby requires geo index which may not be set up
  final response = await api.get(Endpoints.openMats, queryParameters: {
    'page': 1,
    'limit': 20,
  });
  final data = response.data['data'];
  // Handle both array and paginated response shapes
  final List items = data is List ? data : (data is Map ? (data['items'] as List? ?? []) : []);
  return items.map((e) => OpenMat.fromJson(e as Map<String, dynamic>)).toList();
});

final nearbyGymsProvider = FutureProvider.family<List<Gym>, NearbyQuery>((ref, query) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get(Endpoints.gymsNearby, queryParameters: {
    'lat': query.lat,
    'lng': query.lng,
    'radiusKm': query.radiusKm,
  });
  final data = response.data['data'] as List? ?? [];
  return data.map((e) => Gym.fromJson(e as Map<String, dynamic>)).toList();
});

class NearbyQuery {
  final double lat;
  final double lng;
  final int radiusKm;
  final String date;

  const NearbyQuery({required this.lat, required this.lng, this.radiusKm = 25, required this.date});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NearbyQuery && lat == other.lat && lng == other.lng && radiusKm == other.radiusKm && date == other.date;

  @override
  int get hashCode => Object.hash(lat, lng, radiusKm, date);
}

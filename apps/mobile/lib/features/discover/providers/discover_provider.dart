import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../open_mats/models/open_mat.dart';
import '../../search/data/search_query.dart';
import '../../search/data/search_repository.dart';
import '../../gyms/models/gym.dart';

/// Nearby open mats for the discover feed. Delegates to the search repository
/// so the geo query (lat/lng/radiusKm) is actually sent to the API. When the
/// query carries no coordinates, this returns a plain (non-geo) list.
final nearbyOpenMatsProvider =
    FutureProvider.family<List<OpenMat>, NearbyQuery>((ref, query) {
  return ref.watch(searchRepositoryProvider).search(SearchQuery(
        lat: query.lat,
        lng: query.lng,
        radiusKm: query.radiusKm?.toDouble(),
      ));
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

/// Query for the discover feed. [lat]/[lng] are null when the device location
/// is unavailable, in which case a plain (non-geo) list is fetched.
class NearbyQuery {
  final double? lat;
  final double? lng;
  final int? radiusKm;
  final String? date;

  const NearbyQuery({this.lat, this.lng, this.radiusKm = 25, this.date});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NearbyQuery &&
          lat == other.lat &&
          lng == other.lng &&
          radiusKm == other.radiusKm &&
          date == other.date;

  @override
  int get hashCode => Object.hash(lat, lng, radiusKm, date);
}

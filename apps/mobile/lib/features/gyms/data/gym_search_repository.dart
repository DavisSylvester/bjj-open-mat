import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_exception.dart';
import '../models/gym_search_page.dart';
import 'gym_search_query.dart';

abstract class GymSearchRepository {
  Future<GymSearchPage> search(GymSearchQuery query);
}

class ApiGymSearchRepository implements GymSearchRepository {
  final Dio _dio;
  ApiGymSearchRepository(this._dio);

  @override
  Future<GymSearchPage> search(GymSearchQuery query) async {
    try {
      final res = await _dio.get(
        Endpoints.gymsNearby,
        queryParameters: query.toQueryParameters(),
      );
      return GymSearchPage.fromEnvelope(
        res.data as Map<String, dynamic>,
        requestedRadiusKm: query.radiusKm,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final gymSearchRepositoryProvider = Provider<GymSearchRepository>((ref) {
  return ApiGymSearchRepository(ref.read(apiClientProvider).dio);
});

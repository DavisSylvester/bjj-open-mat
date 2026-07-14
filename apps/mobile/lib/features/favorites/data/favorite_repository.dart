import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../../gyms/models/gym.dart';

/// Pure parse step, unit-tested without Dio.
List<Gym> parseFavorites(Map<String, dynamic> body) =>
    unwrapList(body).items.map(Gym.fromJson).toList();

class FavoriteRepository {
  final Dio _dio;
  FavoriteRepository(this._dio);

  Future<List<Gym>> list() async {
    try {
      final res = await _dio.get(Endpoints.myFavorites);
      return parseFavorites(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> add(String gymId) async {
    try {
      await _dio.post(Endpoints.gymFavorite(gymId));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> remove(String gymId) async {
    try {
      await _dio.delete(Endpoints.gymFavorite(gymId));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  return FavoriteRepository(ref.read(apiClientProvider).dio);
});

final myFavoritesProvider = FutureProvider<List<Gym>>((ref) {
  return ref.read(favoriteRepositoryProvider).list();
});

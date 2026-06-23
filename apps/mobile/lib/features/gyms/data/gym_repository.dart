import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/gym.dart';
import 'gym_requests.dart';

abstract class GymRepository {
  Future<List<Gym>> listMine();
  Future<List<Gym>> searchAll(String query);
  Future<Gym> getById(String id);
  Future<Gym> create(CreateGymRequest req);
  Future<Gym> update(String id, UpdateGymRequest req);
}

class ApiGymRepository implements GymRepository {
  final Dio _dio;
  ApiGymRepository(this._dio);

  @override
  Future<List<Gym>> listMine() async {
    try {
      final res = await _dio.get('/api/v1/gyms', queryParameters: {'mine': true});
      final result = unwrapList(res.data as Map<String, dynamic>);
      return result.items.map(Gym.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<Gym> getById(String id) async {
    try {
      final res = await _dio.get('/api/v1/gyms/$id');
      return Gym.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<Gym> create(CreateGymRequest req) async {
    try {
      final res = await _dio.post('/api/v1/gyms', data: req.toJson());
      return Gym.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<Gym> update(String id, UpdateGymRequest req) async {
    try {
      final res = await _dio.put('/api/v1/gyms/$id', data: req.toJson());
      return Gym.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Returns gyms for client-side search/selection (the API has no server-side
  /// name filter yet, so callers filter the returned list locally).
  @override
  Future<List<Gym>> searchAll(String query) async {
    try {
      final res = await _dio.get('/api/v1/gyms', queryParameters: {'limit': 50});
      return unwrapList(res.data as Map<String, dynamic>).items.map(Gym.fromJson).toList();
    } on DioException catch (e) { throw ApiException.fromDio(e); }
  }
}

final gymRepositoryProvider = Provider<GymRepository>((ref) {
  return ApiGymRepository(ref.read(apiClientProvider).dio);
});

final allGymsProvider = FutureProvider<List<Gym>>((ref) => ref.read(gymRepositoryProvider).searchAll(''));

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/open_mat.dart';
import 'session_requests.dart';

abstract class SessionRepository {
  Future<List<OpenMat>> listMine();
  Future<OpenMat> getById(String id);
  Future<OpenMat> create(CreateSessionRequest req);
  Future<OpenMat> update(String id, UpdateSessionRequest req);
}

class ApiSessionRepository implements SessionRepository {
  final Dio _dio;
  ApiSessionRepository(this._dio);

  @override
  Future<List<OpenMat>> listMine() async {
    try {
      final res = await _dio.get('/api/v1/open-mats', queryParameters: {'mine': true});
      return unwrapList(res.data as Map<String, dynamic>).items.map(OpenMat.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<OpenMat> getById(String id) async {
    try {
      final res = await _dio.get('/api/v1/open-mats/$id');
      return OpenMat.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<OpenMat> create(CreateSessionRequest req) async {
    try {
      final res = await _dio.post('/api/v1/open-mats', data: req.toJson());
      return OpenMat.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<OpenMat> update(String id, UpdateSessionRequest req) async {
    try {
      final res = await _dio.put('/api/v1/open-mats/$id', data: req.toJson());
      return OpenMat.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return ApiSessionRepository(ref.read(apiClientProvider).dio);
});

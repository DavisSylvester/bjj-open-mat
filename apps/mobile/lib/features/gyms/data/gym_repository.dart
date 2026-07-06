import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/gym.dart';
import 'gym_requests.dart';

/// Result of requesting a presigned S3 upload slot for a gym logo.
class LogoUploadSlot {
  final String uploadUrl;
  final String publicUrl;
  const LogoUploadSlot({required this.uploadUrl, required this.publicUrl});
}

abstract class GymRepository {
  Future<List<Gym>> listMine();
  Future<List<Gym>> searchAll(String query);
  Future<Gym> getById(String id);
  Future<Gym> create(CreateGymRequest req);
  Future<Gym> update(String id, UpdateGymRequest req);

  /// Uploads [bytes] as a gym logo of [contentType] (image/png|jpeg|webp) and
  /// returns the public URL to store on the gym, or throws on failure.
  Future<String> uploadLogo(Uint8List bytes, String contentType);
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

  @override
  Future<String> uploadLogo(Uint8List bytes, String contentType) async {
    try {
      // 1. Ask the API for a presigned S3 PUT slot (carries our auth token).
      final res = await _dio.post('/api/v1/gyms/logo-upload-url', data: {'contentType': contentType});
      final data = unwrapData(res.data as Map<String, dynamic>);
      final slot = LogoUploadSlot(
        uploadUrl: data['uploadUrl'] as String,
        publicUrl: data['publicUrl'] as String,
      );
      // 2. PUT the bytes straight to S3 with a BARE client — the presigned URL
      // is self-authenticating; sending our Authorization header or baseUrl
      // would break the signature.
      await Dio().put(
        slot.uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            Headers.contentTypeHeader: contentType,
            Headers.contentLengthHeader: bytes.length,
          },
        ),
      );
      return slot.publicUrl;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final gymRepositoryProvider = Provider<GymRepository>((ref) {
  return ApiGymRepository(ref.read(apiClientProvider).dio);
});

final allGymsProvider = FutureProvider<List<Gym>>((ref) => ref.read(gymRepositoryProvider).searchAll(''));

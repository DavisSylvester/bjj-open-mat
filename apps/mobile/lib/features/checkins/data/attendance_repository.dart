import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/checkin.dart';
import 'check_in_request.dart';
import '../../open_mats/data/session_repository.dart';
import '../../open_mats/models/open_mat.dart';

abstract class AttendanceRepository {
  Future<List<CheckIn>> forSession(String openMatId, {String? date});
  Future<CheckIn> checkIn(String openMatId, CreateCheckInRequest req);
}

class ApiAttendanceRepository implements AttendanceRepository {
  final Dio _dio;
  ApiAttendanceRepository(this._dio);

  @override
  Future<List<CheckIn>> forSession(String openMatId, {String? date}) async {
    try {
      final res = await _dio.get('/api/v1/open-mats/$openMatId/checkins',
          queryParameters: {if (date != null) 'date': date});
      return unwrapList(res.data as Map<String, dynamic>).items.map(CheckIn.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<CheckIn> checkIn(String openMatId, CreateCheckInRequest req) async {
    try {
      final res = await _dio.post('/api/v1/open-mats/$openMatId/checkin', data: req.toJson());
      return CheckIn.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return ApiAttendanceRepository(ref.read(apiClientProvider).dio);
});

final sessionByIdProvider = FutureProvider.family<OpenMat, String>((ref, id) {
  return ref.read(sessionRepositoryProvider).getById(id);
});

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/checkin.dart';

abstract class AttendanceRepository {
  Future<List<CheckIn>> forSession(String openMatId, {String? date});
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
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return ApiAttendanceRepository(ref.read(apiClientProvider).dio);
});

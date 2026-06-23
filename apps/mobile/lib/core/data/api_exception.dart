import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String code;
  final String message;
  final int? status;
  const ApiException({required this.code, required this.message, this.status});

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      return ApiException(
        code: err['code']?.toString() ?? 'error',
        message: err['message']?.toString() ?? 'Request failed',
        status: e.response?.statusCode,
      );
    }
    return ApiException(code: 'network_error', message: e.message ?? 'Network error', status: e.response?.statusCode);
  }

  @override
  String toString() => message;
}

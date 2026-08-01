import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

abstract class DeviceRepository {
  Future<void> registerDevice(String token, String platform);
  Future<void> unregisterDevice(String token);
}

class ApiDeviceRepository implements DeviceRepository {
  final Dio _dio;

  ApiDeviceRepository(this._dio);

  @override
  Future<void> registerDevice(String token, String platform) async {
    await _dio.post(Endpoints.devices, data: {'token': token, 'platform': platform});
  }

  @override
  Future<void> unregisterDevice(String token) async {
    await _dio.delete(Endpoints.deviceByToken(token));
  }
}

final deviceRepositoryProvider = Provider<DeviceRepository>(
  (ref) => ApiDeviceRepository(ref.read(apiClientProvider).dio),
);

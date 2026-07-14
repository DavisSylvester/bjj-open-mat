import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/app_notification.dart';

class NotificationRepository {
  final Dio _dio;
  NotificationRepository(this._dio);

  Future<List<AppNotification>> list({int page = 1, int limit = 50}) async {
    try {
      final res = await _dio.get(Endpoints.notifications, queryParameters: {'page': page, 'limit': limit});
      return unwrapList(res.data as Map<String, dynamic>).items.map(AppNotification.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _dio.post(Endpoints.notificationRead(id));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> markAllRead() async {
    try {
      await _dio.post(Endpoints.notificationsReadAll);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.read(apiClientProvider).dio);
});

final myNotificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  return ref.read(notificationRepositoryProvider).list();
});

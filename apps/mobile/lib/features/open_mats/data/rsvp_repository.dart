import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/attendee.dart';

class GoingQuery {
  final String openMatId;
  final String sessionDate;
  const GoingQuery(this.openMatId, this.sessionDate);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoingQuery && openMatId == other.openMatId && sessionDate == other.sessionDate;

  @override
  int get hashCode => Object.hash(openMatId, sessionDate);
}

class RsvpRepository {
  final Dio _dio;
  RsvpRepository(this._dio);

  Future<int> rsvp(String id, String sessionDate) async {
    try {
      final res = await _dio.post(Endpoints.openMatRsvp(id), data: {'sessionDate': sessionDate});
      return (unwrapData(res.data as Map<String, dynamic>)['attendeeCount'] as int?) ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<int> cancel(String id, String sessionDate) async {
    try {
      final res = await _dio.delete(Endpoints.openMatRsvp(id), queryParameters: {'sessionDate': sessionDate});
      return (unwrapData(res.data as Map<String, dynamic>)['attendeeCount'] as int?) ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<Attendee>> attendees(String id, String sessionDate) async {
    try {
      final res = await _dio.get(Endpoints.openMatAttendees(id), queryParameters: {'sessionDate': sessionDate});
      return unwrapList(res.data as Map<String, dynamic>).items.map(Attendee.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final rsvpRepositoryProvider = Provider<RsvpRepository>((ref) {
  return RsvpRepository(ref.read(apiClientProvider).dio);
});

final attendeesProvider = FutureProvider.family<List<Attendee>, GoingQuery>((ref, q) {
  return ref.read(rsvpRepositoryProvider).attendees(q.openMatId, q.sessionDate);
});

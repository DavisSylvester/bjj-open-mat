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
  final int page;
  const GoingQuery(this.openMatId, this.sessionDate, [this.page = 1]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoingQuery &&
          openMatId == other.openMatId &&
          sessionDate == other.sessionDate &&
          page == other.page;

  @override
  int get hashCode => Object.hash(openMatId, sessionDate, page);
}

/// One page of attendees plus the total count across all pages.
class AttendeePage {
  final List<Attendee> items;
  final int total;
  const AttendeePage({required this.items, required this.total});
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

  Future<AttendeePage> attendees(String id, String sessionDate, {int page = 1, int limit = 12}) async {
    try {
      final res = await _dio.get(
        Endpoints.openMatAttendees(id),
        queryParameters: {'sessionDate': sessionDate, 'page': page, 'limit': limit},
      );
      final result = unwrapList(res.data as Map<String, dynamic>);
      return AttendeePage(
        items: result.items.map(Attendee.fromJson).toList(),
        total: result.total,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final rsvpRepositoryProvider = Provider<RsvpRepository>((ref) {
  return RsvpRepository(ref.read(apiClientProvider).dio);
});

final attendeesProvider = FutureProvider.family<AttendeePage, GoingQuery>((ref, q) {
  return ref.read(rsvpRepositoryProvider).attendees(q.openMatId, q.sessionDate, page: q.page);
});

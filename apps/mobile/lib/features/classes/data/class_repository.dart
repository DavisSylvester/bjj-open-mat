import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/class_attendee.dart';
import '../models/gym_class.dart';
import '../models/scheduled_class.dart';

abstract class ClassRepository {
  Future<List<ScheduledClass>> schedule(
    String gymId, {
    required String from,
    required String to,
  });
  Future<List<GymClass>> definitions(String gymId);
  Future<GymClass> create(String gymId, Map<String, dynamic> body);
  Future<GymClass> update(String classId, Map<String, dynamic> body);
  Future<void> archive(String classId);
  Future<void> overrideOccurrence(
    String classId,
    String date,
    Map<String, dynamic> body,
  );
  Future<void> rsvp(String classId, String date);
  Future<void> unrsvp(String classId, String date);
  Future<List<ClassAttendee>> attendees(String classId, String date);
}

class ApiClassRepository implements ClassRepository {
  final Dio _dio;
  ApiClassRepository(this._dio);

  @override
  Future<List<ScheduledClass>> schedule(
    String gymId, {
    required String from,
    required String to,
  }) async {
    try {
      final res = await _dio.get(
        Endpoints.gymSchedule(gymId),
        queryParameters: {'from': from, 'to': to},
      );
      return unwrapList(res.data as Map<String, dynamic>)
          .items
          .map(ScheduledClass.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<List<GymClass>> definitions(String gymId) async {
    try {
      final res = await _dio.get(Endpoints.gymClasses(gymId));
      return unwrapList(res.data as Map<String, dynamic>)
          .items
          .map(GymClass.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<GymClass> create(String gymId, Map<String, dynamic> body) async {
    try {
      final res = await _dio.post(Endpoints.gymClasses(gymId), data: body);
      return GymClass.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<GymClass> update(String classId, Map<String, dynamic> body) async {
    try {
      final res = await _dio.patch(Endpoints.classById(classId), data: body);
      return GymClass.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> archive(String classId) async {
    try {
      await _dio.delete(Endpoints.classById(classId));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> overrideOccurrence(
    String classId,
    String date,
    Map<String, dynamic> body,
  ) async {
    try {
      await _dio.put(Endpoints.classOccurrence(classId, date), data: body);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> rsvp(String classId, String date) async {
    try {
      await _dio.post(Endpoints.classRsvp(classId), data: {'date': date});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> unrsvp(String classId, String date) async {
    try {
      await _dio.delete(Endpoints.classRsvp(classId), data: {'date': date});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<List<ClassAttendee>> attendees(String classId, String date) async {
    try {
      final res = await _dio.get(
        Endpoints.classAttendees(classId),
        queryParameters: {'date': date},
      );
      return unwrapList(res.data as Map<String, dynamic>)
          .items
          .map(ClassAttendee.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final classRepositoryProvider = Provider<ClassRepository>((ref) {
  return ApiClassRepository(ref.read(apiClientProvider).dio);
});

final scheduleProvider = FutureProvider.family<List<ScheduledClass>,
    ({String gymId, String from, String to})>((ref, a) {
  return ref.read(classRepositoryProvider).schedule(
        a.gymId,
        from: a.from,
        to: a.to,
      );
});

final classAttendeesProvider = FutureProvider.family<List<ClassAttendee>,
    ({String classId, String date})>((ref, a) {
  return ref.read(classRepositoryProvider).attendees(a.classId, a.date);
});

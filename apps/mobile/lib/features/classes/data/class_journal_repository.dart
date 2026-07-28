import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/class_journal_entry.dart';
import '../models/instructor_feedback_item.dart';
import '../models/instructor_rating_summary.dart';

abstract class ClassJournalRepository {
  Future<ClassJournalEntry> upsertJournal(
    String classId,
    Map<String, dynamic> body,
  );
  Future<List<ClassJournalEntry>> myJournal({
    required String from,
    required String to,
  });
  Future<List<ClassJournalEntry>> sharedForOccurrence(
    String classId,
    String date,
  );
  Future<void> rateInstructor(String classId, Map<String, dynamic> body);
  Future<InstructorRatingSummary> instructorSummary(String userId);
  Future<List<InstructorFeedbackItem>> gymInstructorFeedback(
    String gymId, {
    String? instructorUserId,
    String? from,
    String? to,
  });
}

class ApiClassJournalRepository implements ClassJournalRepository {
  final Dio _dio;

  ApiClassJournalRepository(this._dio);

  @override
  Future<ClassJournalEntry> upsertJournal(
    String classId,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post(Endpoints.classJournal(classId), data: body);
      return ClassJournalEntry.fromJson(
        unwrapData(res.data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<List<ClassJournalEntry>> myJournal({
    required String from,
    required String to,
  }) async {
    try {
      final res = await _dio.get(
        Endpoints.myJournal,
        queryParameters: {'from': from, 'to': to},
      );
      return unwrapList(res.data as Map<String, dynamic>)
          .items
          .map(ClassJournalEntry.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<List<ClassJournalEntry>> sharedForOccurrence(
    String classId,
    String date,
  ) async {
    try {
      final res = await _dio.get(
        Endpoints.classJournal(classId),
        queryParameters: {'date': date},
      );
      return unwrapList(res.data as Map<String, dynamic>)
          .items
          .map(ClassJournalEntry.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> rateInstructor(String classId, Map<String, dynamic> body) async {
    try {
      await _dio.post(Endpoints.classInstructorRating(classId), data: body);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<InstructorRatingSummary> instructorSummary(String userId) async {
    try {
      final res = await _dio.get(Endpoints.userInstructorRating(userId));
      return InstructorRatingSummary.fromJson(
        unwrapData(res.data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<List<InstructorFeedbackItem>> gymInstructorFeedback(
    String gymId, {
    String? instructorUserId,
    String? from,
    String? to,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        if (instructorUserId != null) 'instructorUserId': instructorUserId,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      };
      final res = await _dio.get(
        Endpoints.gymInstructorFeedback(gymId),
        queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
      );
      return unwrapList(res.data as Map<String, dynamic>)
          .items
          .map(InstructorFeedbackItem.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final classJournalRepositoryProvider = Provider<ClassJournalRepository>(
  (ref) => ApiClassJournalRepository(ref.read(apiClientProvider).dio),
);

final myJournalProvider =
    FutureProvider.family<List<ClassJournalEntry>, ({String from, String to})>(
  (ref, a) =>
      ref.read(classJournalRepositoryProvider).myJournal(from: a.from, to: a.to),
);

final sharedNotesProvider = FutureProvider.family<List<ClassJournalEntry>,
    ({String classId, String date})>(
  (ref, a) => ref
      .read(classJournalRepositoryProvider)
      .sharedForOccurrence(a.classId, a.date),
);

final instructorSummaryProvider =
    FutureProvider.family<InstructorRatingSummary, String>(
  (ref, id) =>
      ref.read(classJournalRepositoryProvider).instructorSummary(id),
);

final gymInstructorFeedbackProvider =
    FutureProvider.family<List<InstructorFeedbackItem>, String>(
  (ref, gymId) =>
      ref.read(classJournalRepositoryProvider).gymInstructorFeedback(gymId),
);

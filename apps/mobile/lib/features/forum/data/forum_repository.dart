import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/forum_answer.dart';
import '../models/forum_question.dart';
import '../models/forum_question_detail.dart';

abstract class ForumRepository {
  Future<List<ForumQuestion>> listQuestions(
    String gymId, {
    String? category,
    int page = 1,
    int limit = 20,
  });
  Future<ForumQuestion> createQuestion(String gymId, Map<String, dynamic> body);
  Future<ForumQuestionDetail> getDetail(String questionId);
  Future<ForumQuestion> updateQuestion(
    String questionId,
    Map<String, dynamic> body,
  );
  Future<void> deleteQuestion(String questionId);
  Future<ForumAnswer> createAnswer(String questionId, String body);
  Future<void> updateAnswer(String answerId, String body);
  Future<void> deleteAnswer(String answerId);
  Future<void> accept(String questionId, String answerId);
}

class ApiForumRepository implements ForumRepository {
  final Dio _dio;
  ApiForumRepository(this._dio);

  @override
  Future<List<ForumQuestion>> listQuestions(
    String gymId, {
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (category != null) 'category': category,
      };
      final res = await _dio.get(
        Endpoints.gymForumQuestions(gymId),
        queryParameters: query,
      );
      return unwrapList(res.data as Map<String, dynamic>)
          .items
          .map(ForumQuestion.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<ForumQuestion> createQuestion(
    String gymId,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post(
        Endpoints.gymForumQuestions(gymId),
        data: body,
      );
      return ForumQuestion.fromJson(
        unwrapData(res.data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<ForumQuestionDetail> getDetail(String questionId) async {
    try {
      final res = await _dio.get(Endpoints.forumQuestion(questionId));
      return ForumQuestionDetail.fromJson(
        unwrapData(res.data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<ForumQuestion> updateQuestion(
    String questionId,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.patch(
        Endpoints.forumQuestion(questionId),
        data: body,
      );
      return ForumQuestion.fromJson(
        unwrapData(res.data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> deleteQuestion(String questionId) async {
    try {
      await _dio.delete(Endpoints.forumQuestion(questionId));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<ForumAnswer> createAnswer(String questionId, String body) async {
    try {
      final res = await _dio.post(
        Endpoints.forumQuestionAnswers(questionId),
        data: {'body': body},
      );
      return ForumAnswer.fromJson(
        unwrapData(res.data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> updateAnswer(String answerId, String body) async {
    try {
      await _dio.patch(
        Endpoints.forumAnswer(answerId),
        data: {'body': body},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> deleteAnswer(String answerId) async {
    try {
      await _dio.delete(Endpoints.forumAnswer(answerId));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> accept(String questionId, String answerId) async {
    try {
      await _dio.post(
        Endpoints.forumQuestionAccept(questionId),
        data: {'answerId': answerId},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final forumRepositoryProvider = Provider<ForumRepository>((ref) {
  return ApiForumRepository(ref.read(apiClientProvider).dio);
});

final forumQuestionsProvider = FutureProvider.family<
    List<ForumQuestion>,
    ({String gymId, String? category})>((ref, a) {
  return ref
      .read(forumRepositoryProvider)
      .listQuestions(a.gymId, category: a.category);
});

final forumQuestionDetailProvider =
    FutureProvider.family<ForumQuestionDetail, String>((ref, id) {
  return ref.read(forumRepositoryProvider).getDetail(id);
});

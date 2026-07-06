import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/checkin.dart';

abstract class ReviewRepository {
  Future<List<CheckIn>> forOpenMat(String openMatId, {int page = 1, int limit = 20});
  Future<void> submitReview(
    String checkInId, {
    required int rating,
    required String review,
    required Map<String, int> categoryRatings,
  });
}

class ApiReviewRepository implements ReviewRepository {
  final Dio _dio;
  ApiReviewRepository(this._dio);

  @override
  Future<List<CheckIn>> forOpenMat(String openMatId, {int page = 1, int limit = 20}) async {
    try {
      final res = await _dio.get(
        '/api/v1/open-mats/$openMatId/reviews',
        queryParameters: {'page': page, 'limit': limit},
      );
      return unwrapList(res.data as Map<String, dynamic>).items.map(CheckIn.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> submitReview(
    String checkInId, {
    required int rating,
    required String review,
    required Map<String, int> categoryRatings,
  }) async {
    try {
      await _dio.post(
        '/api/v1/checkins/$checkInId/review',
        data: {
          'rating': rating,
          'review': review,
          'categoryRatings': categoryRatings,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ApiReviewRepository(ref.read(apiClientProvider).dio);
});

final openMatReviewsProvider = FutureProvider.family<List<CheckIn>, String>((ref, openMatId) {
  return ref.read(reviewRepositoryProvider).forOpenMat(openMatId);
});

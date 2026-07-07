import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/report.dart';

abstract class ReportRepository {
  Future<Report> create({
    required String type,
    required String title,
    required String description,
    List<String> audioKeys = const [],
  });

  Future<List<Report>> listMine();
}

class ApiReportRepository implements ReportRepository {
  final Dio _dio;
  ApiReportRepository(this._dio);

  @override
  Future<Report> create({
    required String type,
    required String title,
    required String description,
    List<String> audioKeys = const [],
  }) async {
    try {
      final res = await _dio.post(Endpoints.reports, data: {
        'type': type,
        'title': title,
        'description': description,
        'audioKeys': audioKeys,
      });
      return Report.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<List<Report>> listMine() async {
    try {
      final res = await _dio.get(Endpoints.reports, queryParameters: {'mine': true});
      return unwrapList(res.data as Map<String, dynamic>).items.map(Report.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ApiReportRepository(ref.read(apiClientProvider).dio),
);

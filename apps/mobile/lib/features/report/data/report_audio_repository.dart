import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';

abstract class ReportAudioRepository {
  Future<({String uploadUrl, String audioKey})> presignUpload(String contentType);
  Future<void> putAudio(String uploadUrl, File file, String contentType);
  Future<({String text, int durationMs})> transcribe(String audioKey);
}

class ApiReportAudioRepository implements ReportAudioRepository {
  final Dio _dio;
  ApiReportAudioRepository(this._dio);

  @override
  Future<({String uploadUrl, String audioKey})> presignUpload(String contentType) async {
    try {
      final res = await _dio.post(Endpoints.reportAudioUploadUrl, data: {'contentType': contentType});
      final d = unwrapData(res.data as Map<String, dynamic>);
      return (uploadUrl: d['uploadUrl'] as String, audioKey: d['audioKey'] as String);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> putAudio(String uploadUrl, File file, String contentType) async {
    final bytes = await file.readAsBytes();
    // Raw PUT straight to S3 (no auth interceptor) — use a bare Dio.
    await Dio().put(uploadUrl, data: Stream.fromIterable([bytes]),
        options: Options(headers: {
          Headers.contentTypeHeader: contentType,
          Headers.contentLengthHeader: bytes.length,
        }));
  }

  @override
  Future<({String text, int durationMs})> transcribe(String audioKey) async {
    try {
      final res = await _dio.post(Endpoints.reportTranscribe, data: {'audioKey': audioKey});
      final d = unwrapData(res.data as Map<String, dynamic>);
      return (text: d['text'] as String, durationMs: (d['durationMs'] as num).toInt());
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final reportAudioRepositoryProvider = Provider<ReportAudioRepository>(
  (ref) => ApiReportAudioRepository(ref.read(apiClientProvider).dio),
);

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:bjj_open_mat/features/report/data/report_audio_repository.dart';

void main() {
  test('presignUpload returns url + key', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    final mock = DioAdapter(dio: dio);
    mock.onPost('/api/v1/reports/audio-upload-url',
        (s) => s.reply(200, {'data': {'uploadUrl': 'https://s3/put', 'audioKey': 'reports/audio/u/a.m4a'}}),
        data: {'contentType': 'audio/mp4'});
    final repo = ApiReportAudioRepository(dio);
    final r = await repo.presignUpload('audio/mp4');
    expect(r.uploadUrl, 'https://s3/put');
    expect(r.audioKey, 'reports/audio/u/a.m4a');
  });

  test('transcribe returns english text', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    final mock = DioAdapter(dio: dio);
    mock.onPost('/api/v1/reports/transcribe',
        (s) => s.reply(200, {'data': {'text': 'hello', 'durationMs': 1200}}),
        data: {'audioKey': 'reports/audio/u/a.m4a'});
    final repo = ApiReportAudioRepository(dio);
    final r = await repo.transcribe('reports/audio/u/a.m4a');
    expect(r.text, 'hello');
    expect(r.durationMs, 1200);
  });
}

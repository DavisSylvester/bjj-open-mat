import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/classes/data/class_repository.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter();

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"data":[{'
      '"classId":"cls1","gymId":"g1","date":"2026-08-04",'
      '"title":"Fundamentals","classType":"gi","giType":"gi",'
      '"skillLevel":"all","startTime":"09:00","endTime":"10:00",'
      '"status":"active","goingCount":3'
      '}],"meta":{"page":1,"limit":1,"total":1}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  test('schedule() parses a list envelope and returns one ScheduledClass', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = _FakeAdapter();
    final repo = ApiClassRepository(dio);
    final result = await repo.schedule('g1', from: '2026-08-01', to: '2026-08-07');
    expect(result, hasLength(1));
    expect(result.single.classId, 'cls1');
    expect(result.single.gymId, 'g1');
    expect(result.single.date, '2026-08-04');
    expect(result.single.title, 'Fundamentals');
    expect(result.single.goingCount, 3);
  });
}

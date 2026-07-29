import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/forum/data/forum_repository.dart';

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
      '{"data":{'
      '"question":{'
      '"id":"q1","gymId":"g1","authorId":"u1","category":"technique",'
      '"title":"How to escape mount?","body":"Looking for tips.",'
      '"pinned":false,"locked":false,"acceptedAnswerId":null,"answerCount":1,'
      '"createdAt":"2026-07-28T00:00:00.000Z","updatedAt":"2026-07-28T00:00:00.000Z"'
      '},'
      '"answers":[{'
      '"id":"a1","questionId":"q1","gymId":"g1","authorId":"u2",'
      '"body":"Bridge and roll.","accepted":false,'
      '"createdAt":"2026-07-28T01:00:00.000Z","updatedAt":"2026-07-28T01:00:00.000Z"'
      '}]'
      '}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  test('getDetail() parses a detail envelope with question + answers', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = _FakeAdapter();
    final repo = ApiForumRepository(dio);
    final result = await repo.getDetail('q1');

    expect(result.question.id, 'q1');
    expect(result.question.gymId, 'g1');
    expect(result.question.title, 'How to escape mount?');
    expect(result.question.category, 'technique');
    expect(result.question.answerCount, 1);

    expect(result.answers, hasLength(1));
    expect(result.answers.single.id, 'a1');
    expect(result.answers.single.questionId, 'q1');
    expect(result.answers.single.body, 'Bridge and roll.');
    expect(result.answers.single.accepted, false);
  });
}

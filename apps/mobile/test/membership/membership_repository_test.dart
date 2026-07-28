import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/membership/data/membership_repository.dart';

class _FakeAdapter implements HttpClientAdapter {
  final Map<String, dynamic> body;
  _FakeAdapter(this.body);
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString(
      '{"data":[{"userId":"u1","name":"A","gymRole":"member","verifiedMember":false,"hasProfile":true}],"meta":{"page":1,"limit":1,"total":1}}',
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }
}

void main() {
  test('roster parses list envelope', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = _FakeAdapter(const {});
    final repo = ApiMembershipRepository(dio);
    final roster = await repo.roster('g1');
    expect(roster.single.userId, 'u1');
  });
}

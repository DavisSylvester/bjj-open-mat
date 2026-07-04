import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:bjj_open_mat/features/checkins/data/attendance_repository.dart';

void main() {
  test('forSession parses check-ins with date query', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3100'));
    final adapter = DioAdapter(dio: dio);
    final repo = ApiAttendanceRepository(dio);
    adapter.onGet('/api/v1/open-mats/om-1/checkins', (s) => s.reply(200, {
      'data': [{'id': 'c-1', 'openMatId': 'om-1', 'userId': 'u-1', 'sessionDate': '2026-06-20', 'checkedInAt': '2026-06-20T19:00:00.000Z', 'userName': 'Sam', 'beltRank': 'blue'}],
      'meta': {'page': 1, 'limit': 1, 'total': 1},
    }), queryParameters: {'date': '2026-06-20'});
    final checkins = await repo.forSession('om-1', date: '2026-06-20');
    expect(checkins.single.userName, 'Sam');
  });
}

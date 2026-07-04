import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:bjj_open_mat/features/open_mats/data/session_repository.dart';
import 'package:bjj_open_mat/features/open_mats/data/session_requests.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ApiSessionRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3100'));
    adapter = DioAdapter(dio: dio);
    repo = ApiSessionRepository(dio);
  });

  test('listMine parses sessions', () async {
    adapter.onGet('/api/v1/open-mats', (s) => s.reply(200, {
      'data': [{'id': 'om-1', 'gymId': 'g-1', 'title': 'Fri', 'startTime': '19:00', 'endTime': '21:00', 'skillLevel': 'all', 'giType': 'gi'}],
      'meta': {'page': 1, 'limit': 20, 'total': 1},
    }), queryParameters: {'mine': true});
    final list = await repo.listMine();
    expect(list.single.giType, 'gi');
  });

  test('create posts the session body', () async {
    adapter.onPost('/api/v1/open-mats', (s) => s.reply(200, {'data': {'id': 'om-9', 'gymId': 'g-1', 'title': 'X', 'startTime': '19:00', 'endTime': '20:00', 'skillLevel': 'all', 'giType': 'both'}}),
        data: Matchers.any);
    final om = await repo.create(const CreateSessionRequest(gymId: 'g-1', title: 'X', startTime: '19:00', endTime: '20:00'));
    expect(om.id, 'om-9');
  });
}

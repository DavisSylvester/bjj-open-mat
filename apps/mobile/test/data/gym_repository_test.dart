import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_repository.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_requests.dart';
import 'package:bjj_open_mat/core/data/api_exception.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ApiGymRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3100'));
    adapter = DioAdapter(dio: dio);
    repo = ApiGymRepository(dio);
  });

  test('listMine sends mine=true and parses the list envelope', () async {
    adapter.onGet('/api/v1/gyms', (s) => s.reply(200, {
      'data': [{'id': 'g-1', 'name': 'Atos', 'address': 'x'}],
      'meta': {'page': 1, 'limit': 20, 'total': 1},
    }), queryParameters: {'mine': true});
    final gyms = await repo.listMine();
    expect(gyms.single.id, 'g-1');
  });

  test('create posts the body and returns the gym', () async {
    adapter.onPost('/api/v1/gyms', (s) => s.reply(200, {'data': {'id': 'g-2', 'name': 'New', 'address': 'y'}}),
        data: {'name': 'New', 'address': 'y'});
    final gym = await repo.create(const CreateGymRequest(name: 'New', address: 'y'));
    expect(gym.id, 'g-2');
  });

  test('maps API error to ApiException', () async {
    adapter.onGet('/api/v1/gyms/missing', (s) => s.reply(404, {'error': {'code': 'not_found', 'message': 'nope'}}));
    expect(() => repo.getById('missing'), throwsA(isA<ApiException>()));
  });
}

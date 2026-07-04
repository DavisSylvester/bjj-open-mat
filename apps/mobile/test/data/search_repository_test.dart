import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:bjj_open_mat/features/search/data/search_repository.dart';
import 'package:bjj_open_mat/features/search/data/search_query.dart';
import 'package:bjj_open_mat/core/data/api_exception.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ApiSearchRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3100'));
    adapter = DioAdapter(dio: dio);
    repo = ApiSearchRepository(dio);
  });

  test('search sends the query params and parses the list envelope', () async {
    adapter.onGet(
      '/api/v1/open-mats',
      (s) => s.reply(200, {
        'data': [
          {
            'id': 'om1',
            'gymId': 'g1',
            'title': 'Sat',
            'startTime': '11:00',
            'endTime': '13:00',
            'giType': 'nogi',
            'gymName': 'NT BJJ',
          }
        ],
        'meta': {'page': 1, 'limit': 50, 'total': 1},
      }),
      queryParameters: {
        'q': 'sat',
        'giType': 'nogi',
        'free': true,
        'zip': '75495',
        'limit': 50,
      },
    );

    final res = await repo.search(
      const SearchQuery(text: 'sat', giType: 'nogi', free: true, zip: '75495'),
    );

    expect(res.single.gymName, 'NT BJJ');
    expect(res.single.giType, 'nogi');
  });

  test('search returns empty list when data is empty', () async {
    adapter.onGet(
      '/api/v1/open-mats',
      (s) => s.reply(200, {
        'data': <Map<String, dynamic>>[],
        'meta': {'page': 1, 'limit': 50, 'total': 0},
      }),
      queryParameters: {
        'limit': 50,
      },
    );

    final res = await repo.search(const SearchQuery());
    expect(res, isEmpty);
  });

  test('maps API error to ApiException', () async {
    adapter.onGet(
      '/api/v1/open-mats',
      (s) => s.reply(500, {'error': {'code': 'internal_error', 'message': 'server error'}}),
      queryParameters: {'limit': 50},
    );

    expect(() => repo.search(const SearchQuery()), throwsA(isA<ApiException>()));
  });
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../../open_mats/models/open_mat.dart';
import 'search_query.dart';

abstract class SearchRepository {
  Future<List<OpenMat>> search(SearchQuery query);
}

class ApiSearchRepository implements SearchRepository {
  final Dio _dio;
  ApiSearchRepository(this._dio);

  @override
  Future<List<OpenMat>> search(SearchQuery query) async {
    try {
      final res = await _dio.get(
        '/api/v1/open-mats',
        queryParameters: query.toQueryParameters(),
      );
      return unwrapList(res.data as Map<String, dynamic>)
          .items
          .map(OpenMat.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return ApiSearchRepository(ref.read(apiClientProvider).dio);
});

final searchResultsProvider =
    FutureProvider.family<List<OpenMat>, SearchQuery>((ref, query) {
  return ref.watch(searchRepositoryProvider).search(query);
});

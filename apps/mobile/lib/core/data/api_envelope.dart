import 'list_result.dart';

/// Unwraps a single-item envelope: { "data": {...} }.
Map<String, dynamic> unwrapData(Map<String, dynamic> body) {
  final data = body['data'];
  if (data is Map<String, dynamic>) return data;
  throw const FormatException('Expected an object under "data"');
}

/// Unwraps a list envelope: { "data": [...], "meta": {page,limit,total} }.
/// Tolerates a bare array under "data" (no meta).
ListResult<Map<String, dynamic>> unwrapList(Map<String, dynamic> body) {
  final raw = body['data'];
  final List list = raw is List ? raw : const [];
  final items = list.cast<Map<String, dynamic>>();
  final meta = body['meta'];
  if (meta is Map<String, dynamic>) {
    return ListResult(
      items: items,
      page: (meta['page'] as num?)?.toInt() ?? 1,
      limit: (meta['limit'] as num?)?.toInt() ?? items.length,
      total: (meta['total'] as num?)?.toInt() ?? items.length,
    );
  }
  return ListResult(items: items, page: 1, limit: items.length, total: items.length);
}

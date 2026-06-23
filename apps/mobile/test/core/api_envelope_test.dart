import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/core/data/api_envelope.dart';

void main() {
  test('unwrapData returns the data object', () {
    expect(unwrapData({'data': {'id': 'x'}}), {'id': 'x'});
  });

  test('unwrapList returns items + meta', () {
    final r = unwrapList({'data': [{'id': 'x'}], 'meta': {'page': 1, 'limit': 20, 'total': 1}});
    expect(r.items.length, 1);
    expect(r.total, 1);
  });

  test('unwrapList tolerates a bare list under data', () {
    final r = unwrapList({'data': [{'id': 'x'}]});
    expect(r.items.length, 1);
    expect(r.total, 1);
  });
}

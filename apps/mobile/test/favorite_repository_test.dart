import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/favorites/data/favorite_repository.dart';

void main() {
  test('parseFavorites maps list envelope to gyms', () {
    final gyms = parseFavorites({
      'data': [
        {'id': 'g1', 'name': 'Atos HQ', 'address': '123 Main St', 'city': 'San Diego', 'state': 'CA', 'rating': 4.8},
        {'id': 'g2', 'name': 'Alliance', 'address': '9 Oak Ave'},
      ],
      'meta': {'page': 1, 'limit': 2, 'total': 2},
    });
    expect(gyms.length, 2);
    expect(gyms.first.name, 'Atos HQ');
    expect(gyms.first.rating, 4.8);
    expect(gyms.last.city, isNull);
  });

  test('parseFavorites tolerates empty data', () {
    expect(parseFavorites({'data': []}), isEmpty);
  });
}

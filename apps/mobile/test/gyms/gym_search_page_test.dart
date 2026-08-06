import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/gyms/models/gym_search_page.dart';

void main() {
  test('parses items, total and effectiveRadiusKm', () {
    final page = GymSearchPage.fromEnvelope(<String, dynamic>{
      'data': [
        {'id': 'g-1', 'name': 'Atos', 'address': 'A', 'distanceKm': 3.2, 'rankBoost': 5, 'sponsored': true},
      ],
      'meta': {'page': 1, 'limit': 20, 'total': 7, 'effectiveRadiusKm': 80.0},
    });
    expect(page.items.single.id, 'g-1');
    expect(page.items.single.sponsored, isTrue);
    expect(page.total, 7);
    expect(page.effectiveRadiusKm, 80.0);
  });

  test('falls back to the requested radius when meta omits effectiveRadiusKm', () {
    final page = GymSearchPage.fromEnvelope(<String, dynamic>{
      'data': <dynamic>[],
      'meta': {'page': 1, 'limit': 20, 'total': 0},
    }, requestedRadiusKm: 40);
    expect(page.effectiveRadiusKm, 40);
  });
}

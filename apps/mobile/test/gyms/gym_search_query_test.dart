import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/gyms/data/gym_search_query.dart';

void main() {
  test('sends coordinates and omits zip when both are present', () {
    const q = GymSearchQuery(lat: 33.4292, lng: -96.5486, zip: '75495', radiusKm: 40);
    final params = q.toQueryParameters();
    expect(params['lat'], 33.4292);
    expect(params['lng'], -96.5486);
    expect(params.containsKey('zip'), isFalse);
  });

  test('sends zip when no coordinates are available', () {
    const q = GymSearchQuery(zip: '75495', radiusKm: 40);
    final params = q.toQueryParameters();
    expect(params['zip'], '75495');
    expect(params.containsKey('lat'), isFalse);
  });

  test('omits blank text', () {
    const q = GymSearchQuery(lat: 1, lng: 2, q: '   ', radiusKm: 40);
    expect(q.toQueryParameters().containsKey('q'), isFalse);
  });

  test('trims text that is sent', () {
    const q = GymSearchQuery(lat: 1, lng: 2, q: '  atos ', radiusKm: 40);
    expect(q.toQueryParameters()['q'], 'atos');
  });

  test('always sends page and limit', () {
    const q = GymSearchQuery(lat: 1, lng: 2, radiusKm: 40, page: 3, limit: 20);
    final params = q.toQueryParameters();
    expect(params['page'], 3);
    expect(params['limit'], 20);
  });
}

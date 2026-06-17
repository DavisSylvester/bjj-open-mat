import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/gyms/models/gym.dart';

void main() {
  test('parses location as {lat,lng} and rating', () {
    final g = Gym.fromJson({
      'id': 'g-1', 'name': 'Atos', 'address': 'x',
      'location': {'lat': 32.9, 'lng': -117.2}, 'rating': 4.8,
    });
    expect(g.location?.lat, 32.9);
    expect(g.location?.lng, -117.2);
    expect(g.rating, 4.8);
  });
}

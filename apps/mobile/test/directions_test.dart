import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/gyms/data/directions.dart';

void main() {
  test('parseDirections reads mapsUrl from data envelope', () {
    final d = parseDirections({
      'data': {
        'latitude': 32.7,
        'longitude': -117.1,
        'address': '123 Main St',
        'mapsUrl': 'https://www.google.com/maps/dir/?api=1&destination=32.7,-117.1',
      },
    });
    expect(d.mapsUrl, 'https://www.google.com/maps/dir/?api=1&destination=32.7,-117.1');
  });

  test('addressMapsUrl builds an encoded search URL', () {
    expect(
      addressMapsUrl('123 Main St, San Diego, CA'),
      'https://www.google.com/maps/search/?api=1&query=123%20Main%20St%2C%20San%20Diego%2C%20CA',
    );
  });
}

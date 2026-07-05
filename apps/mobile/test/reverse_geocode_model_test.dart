import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/core/location/geo_repository.dart';

void main() {
  test('ReverseGeocode.fromJson parses city/state/label', () {
    final r = ReverseGeocode.fromJson({'city': 'Austin', 'state': 'TX', 'label': 'Austin, TX'});
    expect(r.city, 'Austin');
    expect(r.state, 'TX');
    expect(r.label, 'Austin, TX');
  });

  test('empty label falls back to blank', () {
    final r = ReverseGeocode.fromJson({'city': '', 'state': '', 'label': ''});
    expect(r.label, '');
  });
}

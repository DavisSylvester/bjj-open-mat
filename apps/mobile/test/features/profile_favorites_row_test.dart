import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile settings wires a Favorites row to /profile/favorites', () {
    final source = File('lib/features/profile/screens/profile_screen.dart').readAsStringSync();

    expect(source, contains("Text('Favorites'"),
        reason: 'FavoritesScreen is unreachable without a row in the settings card');
    expect(source, contains("context.push('/profile/favorites')"),
        reason: 'the row must navigate to the existing favorites route');
  });

  test('the favorites route it points at still exists', () {
    final router = File('lib/app/router.dart').readAsStringSync();
    expect(router, contains("path: 'favorites'"));
    expect(router, contains('FavoritesScreen'));
  });
}

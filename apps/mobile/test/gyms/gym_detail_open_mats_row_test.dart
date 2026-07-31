import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/features/gyms/screens/gym_detail_screen.dart').readAsStringSync();

  test('gym detail links to the open mats screen', () {
    expect(source, contains("context.push('/gym/\${gym.id}/open-mats')"),
        reason: 'the Open Mats row must route to the dedicated screen');
    expect(source, contains("Text('Open Mats'"));
  });

  test('the inline open mats list is gone', () {
    expect(source, isNot(contains('sessionRowFromOpenMat')),
        reason: 'the list moved to GymOpenMatsScreen; rendering it here too would duplicate it');
    expect(source, isNot(contains('No open mats posted yet.')),
        reason: 'the empty state belongs to the open mats screen now');
  });

  test('the open mats route it points at still exists', () {
    final router = File('lib/app/router.dart').readAsStringSync();
    expect(router, contains("path: 'open-mats'"));
    expect(router, contains('GymOpenMatsScreen'));
  });
}

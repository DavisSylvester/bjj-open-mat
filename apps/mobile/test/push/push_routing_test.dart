import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/push/push_routing.dart';

void main() {
  test('message payload routes to the conversation', () {
    expect(routeForPushData({'type': 'message', 'conversationId': 'c1'}), '/messages/c1');
  });
  test('non-message known type routes to notifications', () {
    expect(routeForPushData({'type': 'forum_answer'}), '/notifications');
  });
  test('unknown/empty payload returns null', () {
    expect(routeForPushData({}), isNull);
  });
}

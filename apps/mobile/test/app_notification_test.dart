import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/notifications/models/app_notification.dart';

void main() {
  test('AppNotification.fromJson parses fields', () {
    final n = AppNotification.fromJson({
      'id': 'n1',
      'type': 'rsvp',
      'title': 'New RSVP',
      'body': 'Alex is going to your Sunday open mat.',
      'read': false,
      'createdAt': '2026-07-14T10:00:00.000Z',
    });
    expect(n.id, 'n1');
    expect(n.type, 'rsvp');
    expect(n.read, false);
  });

  test('AppNotification.fromJson defaults read=false and type=system', () {
    final n = AppNotification.fromJson({'id': 'n2', 'title': 't', 'body': 'b', 'createdAt': ''});
    expect(n.read, false);
    expect(n.type, 'system');
  });

  test('relativeTime buckets minutes/hours/days', () {
    final now = DateTime.utc(2026, 7, 14, 12, 0, 0);
    expect(relativeTime('2026-07-14T11:59:30.000Z', now: now), 'Just now');
    expect(relativeTime('2026-07-14T11:15:00.000Z', now: now), '45m ago');
    expect(relativeTime('2026-07-14T09:00:00.000Z', now: now), '3h ago');
    expect(relativeTime('2026-07-12T12:00:00.000Z', now: now), '2d ago');
    expect(relativeTime('not-a-date', now: now), '');
  });
}

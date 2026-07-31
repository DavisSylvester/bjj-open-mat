import '../../classes/models/scheduled_class.dart';

/// Combines a class's `date` and `startTime` ("HH:mm") into a local DateTime.
///
/// `date` arrives either as "YYYY-MM-DD" or as a full ISO timestamp, so only
/// the first 10 characters are used. Returns null when either part is
/// unparseable — a malformed entry should be skipped, never crash the hub.
DateTime? classStartsAt(ScheduledClass c) {
  if (c.date.length < 10) return null;
  final day = DateTime.tryParse(c.date.substring(0, 10));
  if (day == null) return null;
  final parts = c.startTime.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return DateTime(day.year, day.month, day.day, h, m);
}

/// The single soonest class starting at or after [now], or null if there is none.
///
/// One item, not a list: the hub shows what the user does next, not a schedule.
ScheduledClass? nextUpcoming(List<ScheduledClass> classes, DateTime now) {
  ScheduledClass? best;
  DateTime? bestAt;
  for (final c in classes) {
    final at = classStartsAt(c);
    if (at == null || at.isBefore(now)) continue;
    if (bestAt == null || at.isBefore(bestAt)) {
      best = c;
      bestAt = at;
    }
  }
  return best;
}

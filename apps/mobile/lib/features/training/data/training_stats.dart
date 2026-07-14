import '../../checkins/models/checkin.dart';

typedef TrainingStats = ({int mats, int gyms, int rounds, int streakWeeks});

/// Monday 00:00 of the week containing [d], date-only.
DateTime weekStart(DateTime d) {
  final date = DateTime(d.year, d.month, d.day);
  return date.subtract(Duration(days: date.weekday - 1));
}

/// Real training stats. [totalMats] comes from the list envelope's `total`
/// (the fetched page may be a subset). Streak = consecutive calendar weeks
/// with >=1 check-in counting back from the current week; a current week
/// with no check-in yet defers to last week rather than breaking the streak.
TrainingStats computeTrainingStats(
  List<CheckIn> checkins, {
  required int totalMats,
  DateTime? now,
}) {
  final gyms = <String>{};
  var rounds = 0;
  final weeks = <DateTime>{};
  for (final c in checkins) {
    if (c.gymId != null && c.gymId!.isNotEmpty) gyms.add(c.gymId!);
    rounds += c.rounds ?? 0;
    final d = DateTime.tryParse(c.sessionDate);
    if (d != null) weeks.add(weekStart(d));
  }

  var streak = 0;
  var cursor = weekStart(now ?? DateTime.now());
  if (!weeks.contains(cursor)) cursor = cursor.subtract(const Duration(days: 7));
  while (weeks.contains(cursor)) {
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 7));
  }

  return (mats: totalMats, gyms: gyms.length, rounds: rounds, streakWeeks: streak);
}

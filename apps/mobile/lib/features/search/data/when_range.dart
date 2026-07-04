class WhenRange {
  final DateTime start;
  final DateTime end;
  const WhenRange(this.start, this.end);

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get startIso => _iso(start);
  String get endIso => _iso(end);

  static WhenRange singleDay(DateTime d) =>
      WhenRange(DateTime(d.year, d.month, d.day), DateTime(d.year, d.month, d.day));

  static WhenRange thisWeek(DateTime from) {
    final s = DateTime(from.year, from.month, from.day);
    return WhenRange(s, s.add(const Duration(days: 6)));
  }

  /// Upcoming Saturday..Sunday (inclusive). If today is already the weekend, uses the current one.
  static WhenRange thisWeekend(DateTime from) {
    final base = DateTime(from.year, from.month, from.day);
    final daysUntilSat = (DateTime.saturday - base.weekday) % 7;
    final sat = base.add(Duration(days: daysUntilSat));
    return WhenRange(sat, sat.add(const Duration(days: 1)));
  }

  static WhenRange thisMonth(DateTime from) {
    final s = DateTime(from.year, from.month, 1);
    final e = DateTime(from.year, from.month + 1, 0);
    return WhenRange(s, e);
  }
}

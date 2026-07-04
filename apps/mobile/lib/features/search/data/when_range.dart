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

  /// Rolling 7-day window starting from [from] — NOT a calendar Mon–Sun week.
  static WhenRange thisWeek(DateTime from) {
    final s = DateTime(from.year, from.month, from.day);
    return WhenRange(s, s.add(const Duration(days: 6)));
  }

  /// The current weekend (Sat..Sun). On Sun it uses the current weekend; on other
  /// days it advances to the upcoming Saturday.
  static WhenRange thisWeekend(DateTime from) {
    final base = DateTime(from.year, from.month, from.day);
    final sat = base.weekday == DateTime.sunday
        ? base.subtract(const Duration(days: 1))
        : base.add(Duration(days: (DateTime.saturday - base.weekday) % 7));
    return WhenRange(sat, sat.add(const Duration(days: 1)));
  }

  static WhenRange thisMonth(DateTime from) {
    final s = DateTime(from.year, from.month, 1);
    final e = DateTime(from.year, from.month + 1, 0);
    return WhenRange(s, e);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhenRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

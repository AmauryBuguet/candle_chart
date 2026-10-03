/// The trading sessions [ChartSessions] boxes, in the order it colours them.
enum MarketSession { asia, london, newYork }

/// When [session] opens and closes on the UTC day starting at [day].
({int start, int end}) sessionHours(MarketSession session, int day) {
  const hour = Duration.millisecondsPerHour;
  final date = DateTime.fromMillisecondsSinceEpoch(day, isUtc: true);
  final offset = switch (session) {
    MarketSession.asia => 9,
    MarketSession.london => _ukSummerTime(date) ? 1 : 0,
    MarketSession.newYork => _usSummerTime(date) ? -4 : -5,
  };
  final (open, close) = session == MarketSession.asia ? (9, 18) : (8, 17);
  return (start: day + (open - offset) * hour, end: day + (close - offset) * hour);
}

/// British Summer Time, from the last Sunday of March to the last of October.
bool _ukSummerTime(DateTime date) =>
    !date.isBefore(_lastSunday(date.year, DateTime.march)) && date.isBefore(_lastSunday(date.year, DateTime.october));

/// US daylight saving, from the second Sunday of March to the first of
/// November.
bool _usSummerTime(DateTime date) =>
    !date.isBefore(_nthSunday(date.year, DateTime.march, 2)) &&
    date.isBefore(_nthSunday(date.year, DateTime.november, 1));

DateTime _nthSunday(int year, int month, int n) {
  final first = DateTime.utc(year, month);
  return first.add(Duration(days: (DateTime.sunday - first.weekday) % 7 + 7 * (n - 1)));
}

DateTime _lastSunday(int year, int month) {
  final last = DateTime.utc(year, month + 1, 0);
  return last.subtract(Duration(days: last.weekday % 7));
}

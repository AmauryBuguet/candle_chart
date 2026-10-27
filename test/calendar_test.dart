import 'package:flutter_test/flutter_test.dart';
import 'package:candle_chart/src/internal/calendar.dart';
import 'package:candle_chart/candle_chart.dart';

int _utc(int year, int month, int day, [int hour = 0]) => DateTime.utc(year, month, day, hour).millisecondsSinceEpoch;

void main() {
  group('periods', () {
    test('a day starts at midnight UTC, a week on Monday, a month on the 1st', () {
      // Wednesday 15 October 2025, 13:00.
      final t = _utc(2025, 10, 15, 13);
      expect(ChartLevelPeriod.day.startOf(t), _utc(2025, 10, 15));
      expect(ChartLevelPeriod.week.startOf(t), _utc(2025, 10, 13));
      expect(ChartLevelPeriod.month.startOf(t), _utc(2025, 10, 1));
      expect(ChartLevelPeriod.week.startOf(_utc(2025, 10, 13)), _utc(2025, 10, 13));
      expect(ChartLevelPeriod.week.startOf(_utc(2025, 10, 19, 23)), _utc(2025, 10, 13));
    });

    test('the next period follows on, a month by the calendar', () {
      expect(ChartLevelPeriod.week.nextStart(_utc(2025, 10, 13)), _utc(2025, 10, 20));
      expect(ChartLevelPeriod.month.nextStart(_utc(2025, 12, 1)), _utc(2026, 1, 1));
      expect(ChartLevelPeriod.month.nextStart(_utc(2024, 2, 1)), _utc(2024, 3, 1));
      expect(ChartLevelPeriod.month.previousStart(_utc(2026, 1, 1)), _utc(2025, 12, 1));
      expect(ChartLevelPeriod.week.previousStart(_utc(2025, 10, 13)), _utc(2025, 10, 6));
    });
  });

  group('sessions', () {
    test('Tokyo keeps its hours; London and New York move with their summer time', () {
      // 2025: BST from 30 March to 26 October, US DST from 9 March to 2 November.
      final winter = _utc(2025, 1, 15);
      final summer = _utc(2025, 7, 15);
      expect(sessionHours(MarketSession.asia, winter), (start: _utc(2025, 1, 15, 0), end: _utc(2025, 1, 15, 9)));
      expect(sessionHours(MarketSession.asia, summer), (start: _utc(2025, 7, 15, 0), end: _utc(2025, 7, 15, 9)));
      expect(sessionHours(MarketSession.london, winter), (start: _utc(2025, 1, 15, 8), end: _utc(2025, 1, 15, 17)));
      expect(sessionHours(MarketSession.london, summer), (start: _utc(2025, 7, 15, 7), end: _utc(2025, 7, 15, 16)));
      expect(sessionHours(MarketSession.newYork, winter), (start: _utc(2025, 1, 15, 13), end: _utc(2025, 1, 15, 22)));
      expect(sessionHours(MarketSession.newYork, summer), (start: _utc(2025, 7, 15, 12), end: _utc(2025, 7, 15, 21)));
    });

    test('summer time starts on its Sunday and ends on its other one', () {
      expect(sessionHours(MarketSession.london, _utc(2025, 3, 29)).start, _utc(2025, 3, 29, 8));
      expect(sessionHours(MarketSession.london, _utc(2025, 3, 30)).start, _utc(2025, 3, 30, 7));
      expect(sessionHours(MarketSession.london, _utc(2025, 10, 26)).start, _utc(2025, 10, 26, 8));
      expect(sessionHours(MarketSession.newYork, _utc(2025, 3, 8)).start, _utc(2025, 3, 8, 13));
      expect(sessionHours(MarketSession.newYork, _utc(2025, 3, 9)).start, _utc(2025, 3, 9, 12));
      expect(sessionHours(MarketSession.newYork, _utc(2025, 11, 1)).start, _utc(2025, 11, 1, 12));
      expect(sessionHours(MarketSession.newYork, _utc(2025, 11, 2)).start, _utc(2025, 11, 2, 13));
    });
  });
}

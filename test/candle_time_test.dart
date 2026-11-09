import 'package:flutter_test/flutter_test.dart';
import 'package:candle_chart/src/internal/candle_time.dart';
import 'package:candle_chart/candle_chart.dart';

const _day = 86400000;

ChartCandle _candle(int timestamp) => ChartCandle(
  timestamp: timestamp,
  endTimestamp: timestamp + _day - 1,
  open: 1,
  high: 1,
  low: 1,
  close: 1,
  volume: 0,
);

void main() {
  final candles = [for (var i = 10; i < 15; i++) _candle(i * _day)];

  test('a time inside a candle lands on its open, never the next one', () {
    expect(candleTimeOf(11 * _day + 21 * 3600000, candles), 11 * _day);
    expect(candleTimeOf(11 * _day, candles), 11 * _day);
    expect(candleTimeOf(12 * _day - 1, candles), 11 * _day);
  });

  test('past the last candle it steps by its interval', () {
    expect(candleTimeOf(14 * _day + 5, candles), 14 * _day);
    expect(candleTimeOf(17 * _day + 21 * 3600000, candles), 17 * _day);
  });

  test('before the first candle it steps back by its interval', () {
    expect(candleTimeOf(9 * _day + 21 * 3600000, candles), 9 * _day);
    expect(candleTimeOf(8 * _day, candles), 8 * _day);
  });

  test('with no candles the time is kept', () {
    expect(candleTimeOf(123, const []), 123);
  });

  group('nearest candle', () {
    // Calendar months: 31, 28 and 31 days, so no fixed interval fits them.
    final jan = DateTime.utc(2026).millisecondsSinceEpoch;
    final feb = DateTime.utc(2026, 2).millisecondsSinceEpoch;
    final mar = DateTime.utc(2026, 3).millisecondsSinceEpoch;
    final apr = DateTime.utc(2026, 4).millisecondsSinceEpoch;
    ChartCandle month(int from, int to) =>
        ChartCandle(timestamp: from, endTimestamp: to - 1, open: 1, high: 1, low: 1, close: 1, volume: 0);
    final months = [month(jan, feb), month(feb, mar), month(mar, apr)];

    test('lands on the open of the candle it is in until past its middle', () {
      expect(nearestCandleTime(feb + 13 * _day, months), feb);
      expect(nearestCandleTime(feb + 15 * _day, months), mar);
      expect(nearestCandleTime(jan + 16 * _day, months), feb);
    });

    test('lands on Monday weeks, not on the epoch\'s Thursday', () {
      final monday = DateTime.utc(2026, 11, 2).millisecondsSinceEpoch;
      final weeks = [
        for (var i = 0; i < 3; i++)
          ChartCandle(
            timestamp: monday + i * 7 * _day,
            endTimestamp: monday + (i + 1) * 7 * _day - 1,
            open: 1,
            high: 1,
            low: 1,
            close: 1,
            volume: 0,
          ),
      ];
      expect(nearestCandleTime(monday + 7 * _day + 2 * _day, weeks), monday + 7 * _day);
      expect(nearestCandleTime(monday + 7 * _day + 5 * _day, weeks), monday + 14 * _day);
    });

    test('past either end it steps by the edge candle', () {
      expect(nearestCandleTime(apr + 31 * _day, months), apr + 31 * _day);
      expect(nearestCandleTime(jan - 20 * _day, months), jan - 31 * _day);
    });

    test('in a hole in the candles it stays on the grid of the candle before', () {
      final holed = [_candle(10 * _day), _candle(11 * _day), _candle(15 * _day)];
      expect(nearestCandleTime(12 * _day + 3 * 3600000, holed), 12 * _day);
      expect(nearestCandleTime(13 * _day + 13 * 3600000, holed), 14 * _day);
      expect(nearestCandleTime(14 * _day + 20 * 3600000, holed), 15 * _day);
    });

    test('with no candles the time is kept', () => expect(nearestCandleTime(123, const []), 123));
  });
}

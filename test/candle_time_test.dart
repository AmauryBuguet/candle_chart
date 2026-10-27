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
}

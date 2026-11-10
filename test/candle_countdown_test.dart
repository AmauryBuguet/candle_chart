import 'package:candle_chart/candle_chart.dart';
import 'package:candle_chart/src/internal/candle_countdown.dart';
import 'package:flutter_test/flutter_test.dart';

/// A one-minute candle opening at [open], closing on its last millisecond.
ChartCandle _candle(int open) => ChartCandle(
  timestamp: open,
  endTimestamp: open + 59999,
  open: 1,
  high: 1,
  low: 1,
  close: 1,
  volume: 1,
);

void main() {
  test('a countdown reads mm:ss, then hours and minutes, then days and hours', () {
    expect(formatCountdown(0), '00:00');
    expect(formatCountdown(59 * 1000), '00:59');
    expect(formatCountdown(3599 * 1000), '59:59');
    expect(formatCountdown(3600 * 1000), '1h 00m');
    expect(formatCountdown((23 * 3600 + 59 * 60 + 59) * 1000), '23h 59m');
    expect(formatCountdown(24 * 3600 * 1000), '1d 0h');
    expect(formatCountdown((6 * 24 + 5) * 3600 * 1000 + 1000), '6d 5h');
  });

  test('a countdown rounds up to the second', () {
    expect(formatCountdown(1), '00:01');
    expect(formatCountdown(59001), '01:00');
  });

  test('the countdown runs to the close of the last candle', () {
    final candles = [_candle(0), _candle(60000)];
    expect(candleCountdown(candles, 60000), '01:00');
    expect(candleCountdown(candles, 90000), '00:30');
    expect(candleCountdown(candles, 119999), '00:01');
  });

  test('the countdown holds at zero while the next candle is late, then goes', () {
    final candles = [_candle(0)];
    expect(candleCountdown(candles, 60000), '00:00');
    expect(candleCountdown(candles, 119999), '00:00');
    expect(candleCountdown(candles, 120000), isNull);
    expect(candleCountdown(const [], 0), isNull);
  });
}

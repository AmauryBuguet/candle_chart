import 'package:flutter_test/flutter_test.dart';
import 'package:candle_chart/src/internal/candle_diff.dart';
import 'package:candle_chart/src/internal/candle_time.dart';
import 'package:candle_chart/candle_chart.dart';

ChartCandle _candle(int i, {double close = 100, double volume = 1}) => ChartCandle(
  timestamp: i * 60000,
  endTimestamp: (i + 1) * 60000,
  open: 100,
  high: 101,
  low: 99,
  close: close,
  volume: volume,
);

List<ChartCandle> _candles(int count) => [for (var i = 0; i < count; i++) _candle(i)];

void main() {
  group('firstChangedCandle', () {
    test('the same list, or the same values in new candles, is no change', () {
      final candles = _candles(10);
      expect(firstChangedCandle(candles, candles), isNull);
      expect(firstChangedCandle(candles, _candles(10)), isNull);
      expect(firstChangedCandle(const [], const []), isNull);
    });

    test('the last candle moving is a change from it', () {
      final candles = _candles(10);
      expect(firstChangedCandle(candles, [...candles.take(9), _candle(9, close: 101)]), 9);
    });

    test('a candle appended is a change from where the old list ended', () {
      final candles = _candles(10);
      expect(firstChangedCandle(candles, [...candles, _candle(10)]), 10);
      expect(firstChangedCandle(candles, [...candles.take(9), _candle(9, close: 99), _candle(10)]), 9);
    });

    test('a page prepended is a change from the first candle', () {
      final candles = _candles(10);
      expect(firstChangedCandle(candles, [_candle(-2), _candle(-1), ...candles]), 0);
    });

    test('a list cut short is a change from where it ends', () {
      expect(firstChangedCandle(_candles(10), _candles(7)), 7);
    });

    test('a change anywhere is found, in any field', () {
      final candles = _candles(10);
      List<ChartCandle> replaced(int i, ChartCandle candle) => [...candles]..[i] = candle;
      final c = candles[4];
      final variants = [
        ChartCandle(
          timestamp: c.timestamp + 1,
          endTimestamp: c.endTimestamp,
          open: 100,
          high: 101,
          low: 99,
          close: 100,
          volume: 1,
        ),
        ChartCandle(
          timestamp: c.timestamp,
          endTimestamp: c.endTimestamp + 1,
          open: 100,
          high: 101,
          low: 99,
          close: 100,
          volume: 1,
        ),
        ChartCandle(
          timestamp: c.timestamp,
          endTimestamp: c.endTimestamp,
          open: 100.5,
          high: 101,
          low: 99,
          close: 100,
          volume: 1,
        ),
        ChartCandle(
          timestamp: c.timestamp,
          endTimestamp: c.endTimestamp,
          open: 100,
          high: 102,
          low: 99,
          close: 100,
          volume: 1,
        ),
        ChartCandle(
          timestamp: c.timestamp,
          endTimestamp: c.endTimestamp,
          open: 100,
          high: 101,
          low: 98,
          close: 100,
          volume: 1,
        ),
        _candle(4, close: 100.1),
        _candle(4, volume: 2),
      ];
      for (final variant in variants) {
        expect(firstChangedCandle(candles, replaced(4, variant)), 4);
      }
    });
  });

  test('firstCandleFrom bisects to the first candle opening at or after a time', () {
    final candles = _candles(10);
    expect(firstCandleFrom(-1, candles), 0);
    expect(firstCandleFrom(0, candles), 0);
    expect(firstCandleFrom(1, candles), 1);
    expect(firstCandleFrom(3 * 60000, candles), 3);
    expect(firstCandleFrom(3 * 60000, candles, 5), 5);
    expect(firstCandleFrom(10 * 60000, candles), 10);
    expect(firstCandleFrom(0, const []), 0);
  });
}

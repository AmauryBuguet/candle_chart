import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart/src/painter/position_samples.dart';
import 'package:trading_chart/trading_chart.dart';

const int _minute = 60000;
const int _half = _minute ~/ 2;

ChartCandle _candle(int index, {required double open, required double close}) => ChartCandle(
  timestamp: index * _minute,
  endTimestamp: (index + 1) * _minute,
  open: open,
  high: open > close ? open : close,
  low: open > close ? close : open,
  close: close,
  volume: 1,
);

/// Three candles that gap between each other: 100→105, then opening at 110.
final _candles = [
  _candle(0, open: 100, close: 105),
  _candle(1, open: 110, close: 108),
  _candle(2, open: 103, close: 107),
];

/// The whole run, to the close of the candle still forming.
List<(int, double)> _all({int entry = -_minute}) => positionSamples(
  candles: _candles,
  entryTimestamp: entry,
  exitTimestamp: closeTime(_candles.last),
  exitPrice: _candles.last.close,
);

void main() {
  test('a candle is drawn across its own slot, open then close', () {
    // Bodies are centred on their timestamp, so the open is half an interval
    // before it and the close half an interval after — not, as the candle's
    // own endTimestamp would have it, over the next candle.
    expect(openTime(_candles[1]), _minute - _half);
    expect(closeTime(_candles[1]), _minute + _half);
  });

  test('every candle contributes its open and its close, in that order', () {
    expect(_all(), [
      (-_half, 100.0),
      (_half, 105.0),
      (_half, 110.0),
      (_minute + _half, 108.0),
      (_minute + _half, 103.0),
      (2 * _minute + _half, 107.0),
    ]);
  });

  test('a gap is a step, not a slope', () {
    // One candle's close and the next's open fall at the same instant, so the
    // edge jumps between them rather than drifting across the candle.
    final atBoundary = _all().where((e) => e.$1 == _half).toList();
    expect(atBoundary, [(_half, 105.0), (_half, 110.0)]);
  });

  test('nothing before the entry is traced', () {
    // The entry falls on that candle's body, half an interval after its open,
    // so the run starts at the entry and reaches the close from there.
    expect(_all(entry: _minute).first, (_minute + _half, 108.0));
  });

  test('the candle the entry falls in is picked up from the entry', () {
    // An entry drawn on a candle's body belongs to that candle; tracing back
    // to its open would shade the half of it that came first.
    final samples = _all(entry: _minute);

    expect(samples.map((e) => e.$1), everyElement(greaterThanOrEqualTo(_minute)));
    expect(samples, isNot(contains((_minute - _half, 110.0))));
  });

  test('the run ends on the exit, whatever the candles are doing', () {
    final samples = positionSamples(
      candles: _candles,
      entryTimestamp: 0,
      // Mid-candle, as a close at market is.
      exitTimestamp: _minute,
      exitPrice: 106,
    );

    expect(samples.last, (_minute, 106.0));
    expect(samples.map((e) => e.$1), everyElement(lessThanOrEqualTo(_minute)));
  });

  test('a position with no candles yet is just its exit', () {
    final samples = positionSamples(
      candles: const [],
      entryTimestamp: 0,
      exitTimestamp: _minute,
      exitPrice: 100,
    );

    expect(samples, [(_minute, 100.0)]);
  });
}

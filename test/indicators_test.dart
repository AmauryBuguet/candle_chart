import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart/src/internal/calendar.dart';
import 'package:trading_chart/src/internal/indicators.dart';
import 'package:trading_chart/trading_chart.dart';

List<ChartCandle> _closes(List<double> closes, {int startMs = 0}) => [
  for (var i = 0; i < closes.length; i++)
    ChartCandle(
      timestamp: startMs + i * 60000,
      endTimestamp: startMs + (i + 1) * 60000,
      open: closes[i],
      high: closes[i],
      low: closes[i],
      close: closes[i],
      volume: 1,
    ),
];

List<ChartCandle> _ohlc(List<(double, double, double, double)> bars, {double volume = 1}) => [
  for (var i = 0; i < bars.length; i++)
    ChartCandle(
      timestamp: i * 60000,
      endTimestamp: (i + 1) * 60000,
      open: bars[i].$1,
      high: bars[i].$2,
      low: bars[i].$3,
      close: bars[i].$4,
      volume: volume,
    ),
];

void main() {
  group('SMA', () {
    test('the plain average of the window, null before it fills', () {
      expect(simpleMovingAverage(_closes([1, 2, 3, 4, 5]), 3), [null, null, 2, 3, 4]);
    });
  });

  group('EMA', () {
    test('nothing until the period has accrued, then the simple average seeds it', () {
      final values = exponentialMovingAverage(_closes([1, 2, 3, 4, 5]), 3);

      expect(values.sublist(0, 2), [null, null]);
      expect(values[2], 2);
      // weight 0.5: 2 + (4 - 2) * 0.5 = 3, then 3 + (5 - 3) * 0.5 = 4.
      expect(values[3], 3);
      expect(values[4], 4);
    });

    test('a period longer than the data yields no values', () {
      expect(exponentialMovingAverage(_closes([1, 2]), 3), [null, null]);
    });

    test('a flat series stays put', () {
      final values = exponentialMovingAverage(_closes(List.filled(10, 42)), 4);
      expect(values.sublist(3), everyElement(42));
    });
  });

  group('WMA', () {
    test('the latest close weighs the most', () {
      // (1*1 + 2*2 + 3*3) / 6 = 14 / 6, then (2*1 + 3*2 + 4*3) / 6 = 20 / 6.
      final values = weightedMovingAverage(_closes([1, 2, 3, 4]), 3);
      expect(values[0], isNull);
      expect(values[1], isNull);
      expect(values[2], closeTo(14 / 6, 1e-9));
      expect(values[3], closeTo(20 / 6, 1e-9));
    });
  });

  group('VWAP', () {
    test('accumulates within the day and resets at midnight UTC', () {
      const dayMs = Duration.millisecondsPerDay;
      final candles = [
        const ChartCandle(
          timestamp: dayMs - 120000,
          endTimestamp: dayMs - 60000,
          open: 10,
          high: 12,
          low: 8,
          close: 10,
          volume: 1,
        ),
        const ChartCandle(
          timestamp: dayMs - 60000,
          endTimestamp: dayMs,
          open: 20,
          high: 22,
          low: 18,
          close: 20,
          volume: 3,
        ),
        const ChartCandle(
          timestamp: dayMs,
          endTimestamp: dayMs + 60000,
          open: 30,
          high: 33,
          low: 27,
          close: 30,
          volume: 2,
        ),
      ];
      final values = volumeWeightedAveragePrice(candles);
      expect(values[0], 10);
      // (10 * 1 + 20 * 3) / 4
      expect(values[1], 17.5);
      // A new day: the running sums start over.
      expect(values[2], 30);
    });

    test('a candle with no volume carries the running value', () {
      final candles = [
        const ChartCandle(timestamp: 0, endTimestamp: 60000, open: 10, high: 10, low: 10, close: 10, volume: 2),
        const ChartCandle(timestamp: 60000, endTimestamp: 120000, open: 50, high: 50, low: 50, close: 50, volume: 0),
      ];
      expect(volumeWeightedAveragePrice(candles), [10, 10]);
    });
  });

  group('Bollinger', () {
    test('the bands sit a deviation either side of the simple average', () {
      final bands = bollingerBands(_closes([2, 4, 4, 4, 5, 5, 7, 9]), 8, 2);

      expect(bands.sublist(0, 7), everyElement(isNull));
      final band = bands.last!;
      expect(band.middle, 5);
      // Population standard deviation of this series is exactly 2.
      expect(band.upper, closeTo(9, 1e-9));
      expect(band.lower, closeTo(1, 1e-9));
    });

    test('the window slides', () {
      final bands = bollingerBands(_closes([1, 1, 1, 10, 10, 10]), 3, 1);
      expect(bands[2]!.middle, 1);
      expect(bands[2]!.upper, closeTo(1, 1e-9));
      expect(bands[5]!.middle, 10);
      expect(bands[5]!.lower, closeTo(10, 1e-9));
    });
  });

  group('RSI', () {
    test('all gains read 100, all losses 0, and the first value is the plain average', () {
      expect(relativeStrengthIndex(_closes([1, 2, 3, 4]), 3)[3], 100);
      expect(relativeStrengthIndex(_closes([4, 3, 2, 1]), 3)[3], 0);
    });

    test("Wilder's smoothing after the seed", () {
      // Changes: +1, -1, +1 over the seed period, then +3.
      // Seed: gain 2/3, loss 1/3 → RS 2 → RSI 66.67.
      // Next: gain (2/3 * 2 + 3) / 3 = 13/9, loss (1/3 * 2 + 0) / 3 = 2/9 → RS 6.5 → RSI 86.67.
      final values = relativeStrengthIndex(_closes([10, 11, 10, 11, 14]), 3);
      expect(values.sublist(0, 3), everyElement(isNull));
      expect(values[3], closeTo(100 - 100 / 3, 1e-9));
      expect(values[4], closeTo(100 - 100 / 7.5, 1e-9));
    });
  });

  group('MACD', () {
    test('the fast EMA less the slow one, the signal seeded on the first MACD values', () {
      final closes = [for (var i = 1; i <= 8; i++) i.toDouble()];
      final values = macd(_closes(closes), 2, 3, 2);
      final fast = exponentialMovingAverage(_closes(closes), 2);
      final slow = exponentialMovingAverage(_closes(closes), 3);
      // MACD exists from index 2 (the slow EMA's first value); the signal
      // needs two of them, so the first full reading is at index 3.
      expect(values.sublist(0, 3), everyElement(isNull));
      final line2 = fast[2]! - slow[2]!;
      final line3 = fast[3]! - slow[3]!;
      expect(values[3]!.macd, closeTo(line3, 1e-9));
      expect(values[3]!.signal, closeTo((line2 + line3) / 2, 1e-9));
      expect(values[3]!.histogram, closeTo(line3 - (line2 + line3) / 2, 1e-9));
    });
  });

  group('Stochastic', () {
    test('%K is where the close sits in the window, %D its average', () {
      final candles = _ohlc([
        (1, 10, 0, 5), // window fills at index 2
        (1, 10, 0, 5),
        (1, 10, 0, 10), // raw %K 100
        (1, 10, 0, 0), // raw 0
        (1, 10, 0, 5), // raw 50
        (1, 10, 0, 10), // raw 100
      ]);
      final values = stochastic(candles, 3, 1, 2);
      // %K unsmoothed = raw; %D averages two: (100, 0) → 50 at index 3.
      expect(values.sublist(0, 3), everyElement(isNull));
      expect(values[3]!.k, 0);
      expect(values[3]!.d, 50);
      expect(values[5]!.k, 100);
      expect(values[5]!.d, 75);
    });

    test('a flat window reads 50', () {
      final values = stochastic(_closes([5, 5, 5, 5]), 3, 1, 1);
      expect(values[3]!.k, 50);
    });
  });

  group('Ichimoku', () {
    test('each line is the midpoint of its window, span A the mean of the first two', () {
      final candles = _ohlc([
        (1, 10, 0, 5),
        (1, 20, 10, 15),
        (1, 30, 20, 25),
        (1, 40, 30, 35),
      ]);
      final values = ichimoku(candles, 2, 3, 4);
      expect(values.sublist(0, 3), everyElement(isNull));
      final last = values[3]!;
      // Conversion over the last 2: (40 + 20) / 2; base over 3: (40 + 10) / 2; span B over 4: (40 + 0) / 2.
      expect(last.conversion, 30);
      expect(last.base, 25);
      expect(last.spanA, 27.5);
      expect(last.spanB, 20);
    });
  });

  group('ATR', () {
    test('the true range reaches to the previous close, then smooths', () {
      final candles = _ohlc([
        (10, 12, 8, 10), // range 4
        (10, 11, 9, 10), // range 2
        (10, 20, 15, 18), // high - previous close = 10
      ]);
      final values = averageTrueRange(candles, 2);
      expect(values[0], isNull);
      expect(values[1], 3);
      // (3 * 1 + 10) / 2
      expect(values[2], 6.5);
    });
  });

  group('SuperTrend', () {
    test('trails under a rising market and flips over it when the close breaks the band', () {
      final rising = _ohlc([for (var i = 0; i < 6; i++) (10.0 + i, 11.0 + i, 9.0 + i, 10.0 + i)]);
      final up = superTrend(rising, 2, 1);
      expect(up[1]!.up, isTrue);
      expect(up.last!.up, isTrue);
      expect(up.last!.value, lessThan(rising.last.close));

      // Then a drop through the lower band.
      final falling = [
        ...rising,
        const ChartCandle(
          timestamp: 6 * 60000,
          endTimestamp: 7 * 60000,
          open: 15,
          high: 15,
          low: 5,
          close: 5,
          volume: 1,
        ),
      ];
      final flipped = superTrend(falling, 2, 1);
      expect(flipped.last!.up, isFalse);
      expect(flipped.last!.value, greaterThan(5));
    });
  });

  group('period levels', () {
    const hour = Duration.millisecondsPerHour;
    final monday = DateTime.utc(2025, 10, 13).millisecondsSinceEpoch;

    List<ChartCandle> hourly(int from, int count, {int intervalMs = hour}) => [
      for (var i = 0; i < count; i++)
        ChartCandle(
          timestamp: from + i * intervalMs,
          endTimestamp: from + (i + 1) * intervalMs,
          open: 100.0 + i,
          high: 101.0 + i,
          low: 99.0 + i,
          close: 100.5 + i,
          volume: 1,
        ),
    ];

    ChartPeriodLevels day({ChartPeriodRange? previous, ChartPeriodRange? current}) => ChartPeriodLevels(
      period: ChartLevelPeriod.day,
      previousHighColor: null,
      previousLowColor: null,
      openColor: null,
      highColor: null,
      lowColor: null,
      previous: previous,
      current: current,
    );

    test("the current day's levels from its first candle: yesterday's range, its open, its range so far", () {
      final levels = periodLevels(hourly(monday, 30), day())!;
      expect(levels.from, 24);
      // Day one ran from 99 (its first low) to 124 (its last high).
      expect((levels.previousHigh, levels.previousLow), (124.0, 99.0));
      expect((levels.open, levels.high, levels.low), (124.0, 130.0, 123.0));
    });

    test('a day the candles do not cover in full gives nothing of it', () {
      final levels = periodLevels(hourly(monday + 6 * hour, 24), day())!;
      expect((levels.previousHigh, levels.previousLow), (null, null));
      expect(levels.open, 118.0);
      final midway = periodLevels(hourly(monday + 30 * hour, 4), day())!;
      expect((midway.open, midway.high, midway.low), (null, 104.0, 99.0));
    });

    test("the host's ranges stand in for what the candles lack, the current one carried on by them", () {
      final candles = hourly(monday + 30 * hour, 4);
      final today = monday + 24 * hour;
      final levels = periodLevels(
        candles,
        day(
          previous: ChartPeriodRange(start: monday, open: 90, high: 140, low: 80),
          current: ChartPeriodRange(start: today, open: 95, high: 102, low: 96),
        ),
      )!;
      expect((levels.previousHigh, levels.previousLow), (140.0, 80.0));
      // The candles since reach 104 and go no lower than 96 already held.
      expect((levels.open, levels.high, levels.low), (95.0, 104.0, 96.0));

      final stale = periodLevels(
        candles,
        day(previous: ChartPeriodRange(start: monday - 24 * hour, open: 1, high: 2, low: 1)),
      )!;
      expect(stale.previousHigh, isNull);
    });

    test('candles as long as the period show nothing', () {
      expect(periodLevels(hourly(monday, 10, intervalMs: Duration.millisecondsPerDay), day()), isNull);
    });
  });

  group('sessions', () {
    const hour = Duration.millisecondsPerHour;
    // Wednesday 15 October 2025, in London and New York summer time.
    final day = DateTime.utc(2025, 10, 15).millisecondsSinceEpoch;

    List<ChartCandle> hourly(int from, int count, {int intervalMs = hour}) => [
      for (var i = 0; i < count; i++)
        ChartCandle(
          timestamp: from + i * intervalMs,
          endTimestamp: from + (i + 1) * intervalMs,
          open: 100,
          high: 100.0 + i,
          low: 100.0 - i,
          close: 100,
          volume: 1,
        ),
    ];

    test('each session spans its hours and the range of the candles opening in them', () {
      final ranges = sessionRanges(hourly(day, 24));
      expect(ranges.map((r) => r.session), MarketSession.values);
      expect(ranges[0], (session: MarketSession.asia, start: day, end: day + 9 * hour, high: 108.0, low: 92.0));
      expect(ranges[1], (
        session: MarketSession.london,
        start: day + 7 * hour,
        end: day + 16 * hour,
        high: 115.0,
        low: 85.0,
      ));
      expect(ranges[2], (
        session: MarketSession.newYork,
        start: day + 12 * hour,
        end: day + 21 * hour,
        high: 120.0,
        low: 80.0,
      ));
    });

    test('the live session spans what it has so far; one opened before the candles is left out', () {
      final ranges = sessionRanges(hourly(day + 3 * hour, 11));
      expect(ranges.map((r) => r.session), [MarketSession.london, MarketSession.newYork]);
      expect(ranges[1].high, 110);
    });

    test('candles longer than an hour show none', () {
      expect(sessionRanges(hourly(day, 6, intervalMs: 4 * hour)), isEmpty);
    });

    test("none on a weekend: Friday's three sessions, then Monday's", () {
      final friday = DateTime.utc(2025, 10, 17).millisecondsSinceEpoch;
      final ranges = sessionRanges(hourly(friday, 4 * 24));
      expect(ranges.map((r) => r.session), [...MarketSession.values, ...MarketSession.values]);
      expect(ranges[3].start, friday + 3 * Duration.millisecondsPerDay);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart/src/internal/indicators.dart';
import 'package:trading_chart/trading_chart.dart';

List<ChartCandle> _closes(List<double> closes) => [
  for (var i = 0; i < closes.length; i++)
    ChartCandle(
      timestamp: i * 60000,
      endTimestamp: (i + 1) * 60000,
      open: closes[i],
      high: closes[i],
      low: closes[i],
      close: closes[i],
      volume: 1,
    ),
];

void main() {
  bollingerTests();

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
}

void bollingerTests() {
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
}

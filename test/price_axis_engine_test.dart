import 'package:flutter_test/flutter_test.dart';
import 'package:candle_chart/src/internal/chart_controller.dart';
import 'package:candle_chart/src/internal/price_axis_engine.dart';
import 'package:candle_chart/candle_chart.dart';

List<ChartCandle> _candles(List<(double, double)> lowHighs, {int start = 0}) => [
  for (var i = 0; i < lowHighs.length; i++)
    ChartCandle(
      timestamp: start + i * 60000,
      endTimestamp: start + (i + 1) * 60000,
      open: lowHighs[i].$1,
      high: lowHighs[i].$2,
      low: lowHighs[i].$1,
      close: lowHighs[i].$2,
      volume: 1,
    ),
];

void main() {
  const timeAxis = TimeAxis(start: 0, end: 10 * 60000);

  test('fits the visible candles with the margin above and below', () {
    final engine = PriceAxisEngine()..recompute(candles: _candles([(1, 1000)]), timeAxis: timeAxis, priceMargin: 0.1);
    expect(engine.axis, const PriceAxis(start: 1 - 99.9, end: 1000 + 99.9));
  });

  test('a fit of one price still opens the axis', () {
    final engine = PriceAxisEngine()..recompute(candles: _candles([(50, 50)]), timeAxis: timeAxis, priceMargin: 0.1);
    expect(engine.axis.start, lessThan(50));
    expect(engine.axis.end, greaterThan(50));
  });

  test('changing the price margin keeps the time window and refits the prices', () {
    final candles = _candles([
      for (var i = 0; i < 40; i++) (100.0 + i, 110.0 + i),
    ], start: DateTime.now().millisecondsSinceEpoch - 40 * 60000);
    final controller = ChartController(
      interval: const Duration(minutes: 1),
      viewConfig: const ChartViewConfig(),
      candles: candles,
      viewResetKey: 'BTC',
      formatPrice: (price) => price.toStringAsFixed(1),
      labelStyle: const ChartLabelStyle(),
      indicators: const [],
      colors: const ChartColors(),
    )..panByFraction(-0.5);
    final panned = controller.timeAxis;
    final before = controller.priceAxis;
    controller.updateInputs(
      interval: const Duration(minutes: 1),
      viewConfig: const ChartViewConfig(priceMargin: 0.3),
      candles: candles,
      viewResetKey: 'BTC',
      formatPrice: (price) => price.toStringAsFixed(1),
      labelStyle: const ChartLabelStyle(),
      indicators: const [],
      colors: const ChartColors(),
    );
    expect(controller.timeAxis, panned);
    expect(controller.priceAxis, isNot(before));
  });
}

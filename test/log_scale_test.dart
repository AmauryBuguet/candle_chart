import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart/src/internal/chart_controller.dart';
import 'package:trading_chart/src/internal/price_axis_engine.dart';
import 'package:trading_chart/trading_chart.dart';

void main() {
  const transform = ChartTransform(
    size: Size(400, 300),
    margins: ChartMargins(left: 0, top: 0, right: 0, bottom: 0),
    priceAxis: PriceAxis(start: 10, end: 1000),
    timeAxis: TimeAxis(start: 1000, end: 2000),
    logScale: true,
  );

  test('equal ratios take equal heights on a log scale', () {
    expect(transform.yForPrice(10), 300);
    expect(transform.yForPrice(1000), 0);
    expect(transform.yForPrice(100), closeTo(150, 1e-9));
  });

  test('round-trips through the log mapping', () {
    expect(transform.priceForY(transform.yForPrice(37)), closeTo(37, 1e-9));
    expect(transform.priceForY(75), closeTo(316.2277, 1e-3));
  });

  _fitTests();
}

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

void _fitTests() {
  const timeAxis = TimeAxis(start: 0, end: 10 * 60000);

  test('a log fit keeps the same room above and below, whatever the range', () {
    final engine = PriceAxisEngine()
      ..recompute(candles: _candles([(1, 1000), (2, 500)]), timeAxis: timeAxis, priceMargin: 0.1, logScale: true);
    expect(engine.axis.start, greaterThan(0));
    expect(1 / engine.axis.start, closeTo(engine.axis.end / 1000, 1e-9));
    expect(engine.axis.end / 1000, closeTo(1.9953, 1e-3));
  });

  test('a log fit of one price still opens the axis', () {
    final engine = PriceAxisEngine()
      ..recompute(candles: _candles([(50, 50)]), timeAxis: timeAxis, priceMargin: 0.1, logScale: true);
    expect(engine.axis.start, lessThan(50));
    expect(engine.axis.end, greaterThan(50));
  });

  test('switching the scale keeps the time window and refits the prices', () {
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
    final linear = controller.priceAxis;
    controller.updateInputs(
      interval: const Duration(minutes: 1),
      viewConfig: const ChartViewConfig(logScale: true),
      candles: candles,
      viewResetKey: 'BTC',
      formatPrice: (price) => price.toStringAsFixed(1),
      labelStyle: const ChartLabelStyle(),
      indicators: const [],
      colors: const ChartColors(),
    );
    expect(controller.timeAxis, panned);
    expect(controller.priceAxis, isNot(linear));
  });

  test('a linear fit is unchanged', () {
    final engine = PriceAxisEngine()..recompute(candles: _candles([(1, 1000)]), timeAxis: timeAxis, priceMargin: 0.1);
    expect(engine.axis, const PriceAxis(start: 1 - 99.9, end: 1000 + 99.9));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart/src/internal/chart_controller.dart';
import 'package:trading_chart/trading_chart.dart';

List<ChartCandle> _candles() {
  final start = DateTime.now().millisecondsSinceEpoch - 40 * 60000;
  return [
    for (var i = 0; i < 40; i++)
      ChartCandle(
        timestamp: start + i * 60000,
        endTimestamp: start + (i + 1) * 60000,
        open: 100,
        high: 101,
        low: 99,
        close: 100,
        volume: 1,
      ),
  ];
}

ChartController _controller(ChartLabelStyle labelStyle) => ChartController(
  interval: const Duration(minutes: 1),
  viewConfig: const ChartViewConfig(),
  candles: _candles(),
  viewResetKey: 'BTC',
  formatPrice: (price) => price.toStringAsFixed(4),
  labelStyle: labelStyle,
  indicators: const [],
  colors: const ChartColors(),
);

double _textWidth(String text, TextStyle style) =>
    (TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout()).width;

void main() {
  test('the price axis is as wide as its longest tick, in the label style', () {
    const labelStyle = ChartLabelStyle(
      textStyle: TextStyle(fontSize: 10),
      labelMargin: 4,
    );
    final controller = _controller(labelStyle);

    final start = controller.priceAxis.start.toStringAsFixed(4);
    final end = controller.priceAxis.end.toStringAsFixed(4);
    final longest = start.length > end.length ? start : end;
    expect(
      controller.margins.right,
      4 + _textWidth(longest, labelStyle.textStyle) + 4,
    );
  });

  test('the axis is resized when the label style changes', () {
    final controller = _controller(
      const ChartLabelStyle(textStyle: TextStyle(fontSize: 10)),
    );
    final before = controller.margins.right;

    controller.updateInputs(
      interval: const Duration(minutes: 1),
      viewConfig: const ChartViewConfig(),
      candles: _candles(),
      viewResetKey: 'BTC',
      formatPrice: (price) => price.toStringAsFixed(4),
      labelStyle: const ChartLabelStyle(textStyle: TextStyle(fontSize: 20)),
      indicators: const [],
      colors: const ChartColors(),
    );

    expect(controller.margins.right, greaterThan(before));
  });
}

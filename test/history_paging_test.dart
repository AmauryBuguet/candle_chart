import 'package:flutter_test/flutter_test.dart';
import 'package:candle_chart/src/internal/chart_controller.dart';
import 'package:candle_chart/candle_chart.dart';

List<ChartCandle> _candles(int count) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    for (var i = 0; i < count; i++)
      ChartCandle(
        timestamp: now - (count - i) * 60000,
        endTimestamp: now - (count - i - 1) * 60000,
        open: 100,
        high: 101,
        low: 99,
        close: 100,
        volume: 1,
      ),
  ];
}

void main() {
  test('nearing the oldest candle asks for what comes before it, once', () {
    final asked = <int>[];
    final candles = _candles(200);
    final controller = ChartController(
      interval: const Duration(minutes: 1),
      viewConfig: const ChartViewConfig(startCandles: 100),
      candles: candles,
      viewResetKey: 'BTC',
      formatPrice: (price) => price.toStringAsFixed(1),
      labelStyle: const ChartLabelStyle(),
      indicators: const [],
      colors: const ChartColors(),
    )..onNeedMoreHistory = asked.add;

    controller.panByFraction(-0.5);
    expect(asked, isEmpty);
    controller.panByFraction(-0.5);
    controller.panByFraction(-0.5);
    expect(asked, [candles.first.timestamp]);
    controller.panByFraction(-0.5);
    expect(asked, hasLength(1));
  });
}

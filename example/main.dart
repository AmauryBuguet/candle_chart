import 'dart:math';

import 'package:candle_chart/candle_chart.dart';
import 'package:flutter/material.dart';

void main() => runApp(
  const MaterialApp(
    home: Scaffold(body: SafeArea(child: ExampleChart())),
  ),
);

/// A random walk of hourly candles with an EMA, volume and RSI.
class ExampleChart extends StatelessWidget {
  const ExampleChart({super.key});

  static const interval = Duration(hours: 1);

  static List<ChartCandle> _candles() {
    final random = Random(7);
    final start = DateTime.now().subtract(interval * 300).millisecondsSinceEpoch;
    var close = 100.0;
    return List.generate(300, (i) {
      final open = close;
      close = max(1, open + (random.nextDouble() - 0.5) * 2);
      final time = start + i * interval.inMilliseconds;
      return ChartCandle(
        timestamp: time,
        endTimestamp: time + interval.inMilliseconds - 1,
        open: open,
        high: max(open, close) + random.nextDouble(),
        low: min(open, close) - random.nextDouble(),
        close: close,
        volume: 100 + random.nextDouble() * 900,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return TradingChart(
      candles: _candles(),
      lines: const [],
      orderLines: const [],
      positions: const [],
      style: const ChartStyle(),
      indicators: const [
        ChartEma(period: 20, color: Colors.amber),
        ChartVolume(),
        ChartRsi(color: Colors.purple),
      ],
      interval: interval,
      viewConfig: const ChartViewConfig(),
      viewResetKey: 'example',
      formatPrice: (price) => price.toStringAsFixed(2),
      onPointerDownInChart: (pos, priceAxis, timeAxis, isMobile) {},
      onPointerDownOutsideChart: () {},
      onDragUpdate: (delta, coord, priceAxis) => false,
      onDragEnd: () async {},
    );
  }
}

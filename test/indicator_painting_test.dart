import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart/trading_chart.dart';

List<ChartCandle> _candles() {
  final start = DateTime.now().millisecondsSinceEpoch - 40 * 60000;
  return [
    for (var i = 0; i < 40; i++)
      ChartCandle(
        timestamp: start + i * 60000,
        endTimestamp: start + (i + 1) * 60000,
        open: 100.0 + i,
        high: 102.0 + i,
        low: 99.0 + i,
        close: 101.0 + i,
        volume: i.toDouble(),
      ),
  ];
}

Future<void> _pumpChart(WidgetTester tester, ChartStyle style) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TradingChart(
          candles: _candles(),
          lines: const [],
          orderLines: const [],
          positions: const [],
          style: style,
          interval: const Duration(minutes: 1),
          viewConfig: const ChartViewConfig(),
          viewResetKey: 'BTC',
          formatPrice: (price) => price.toStringAsFixed(1),
          onPointerDownInChart: (_, _, _, _) {},
          onPointerDownOutsideChart: () {},
          onDragUpdate: (_, _, _) => false,
          onDragEnd: () async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('volume bars, moving averages and Bollinger Bands paint without error', (tester) async {
    await _pumpChart(
      tester,
      const ChartStyle(
        volume: true,
        emas: [ChartEma(period: 5, color: Colors.blue), ChartEma(period: 100, color: Colors.red)],
        bollinger: ChartBollinger(period: 20, deviation: 2, color: Colors.grey),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

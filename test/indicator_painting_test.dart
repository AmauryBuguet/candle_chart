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

Future<void> _pumpChart(WidgetTester tester, List<ChartIndicator> indicators) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TradingChart(
          candles: _candles(),
          lines: const [],
          orderLines: const [],
          positions: const [],
          style: const ChartStyle(),
          indicators: indicators,
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
  testWidgets('every overlay paints without error, including one longer than the data', (tester) async {
    await _pumpChart(tester, const [
      ChartSma(period: 5, color: Colors.blue),
      ChartEma(period: 5, color: Colors.blue),
      ChartEma(period: 100, color: Colors.red),
      ChartWma(period: 5, color: Colors.green),
      ChartVwap(color: Colors.orange),
      ChartBollinger(period: 20, deviation: 2, color: Colors.grey),
      ChartIchimoku(
        conversionColor: Colors.blue,
        baseColor: Colors.red,
        spanAColor: Colors.green,
        spanBColor: Colors.red,
        laggingColor: Colors.purple,
      ),
      ChartSuperTrend(upColor: Colors.green, downColor: Colors.red),
      ChartVolumeProfile(color: Colors.grey, pocColor: Colors.blue),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every pane indicator gets a pane of its own under the price pane', (tester) async {
    final controller = TradingChartController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TradingChart(
            candles: _candles(),
            lines: const [],
            orderLines: const [],
            positions: const [],
            style: const ChartStyle(),
            indicators: const [
              ChartVolume(),
              ChartRsi(color: Colors.blue),
              ChartMacd(macdColor: Colors.blue, signalColor: Colors.red, upColor: Colors.green, downColor: Colors.red),
              ChartStochastic(kColor: Colors.blue, dColor: Colors.red),
            ],
            interval: const Duration(minutes: 1),
            viewConfig: const ChartViewConfig(),
            viewResetKey: 'BTC',
            formatPrice: (price) => price.toStringAsFixed(1),
            onPointerDownInChart: (_, _, _, _) {},
            onPointerDownOutsideChart: () {},
            onDragUpdate: (_, _, _) => false,
            onDragEnd: () async {},
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final transform = controller.transform!;
    expect(transform.panes, hasLength(4));
    // Panes stack under the price pane, top to bottom, none overlapping.
    var bottom = transform.plotArea.bottom;
    for (final pane in transform.panes) {
      expect(pane.rect.top, greaterThan(bottom));
      bottom = pane.rect.bottom;
    }
    expect(bottom, closeTo(transform.size.height - transform.margins.bottom, 1e-6));
    // A bounded oscillator keeps its fixed range whatever is visible.
    expect(transform.panes[1].axis, const PriceAxis(start: 0, end: 100));
  });
}

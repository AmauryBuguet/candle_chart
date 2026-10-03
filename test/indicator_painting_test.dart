import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart/src/painter/chart_painter.dart';
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

Future<void> _pumpChart(
  WidgetTester tester,
  List<ChartIndicator> indicators, {
  List<ChartCandle>? candles,
  Duration interval = const Duration(minutes: 1),
  ChartStyle style = const ChartStyle(),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TradingChart(
          candles: candles ?? _candles(),
          lines: const [],
          orderLines: const [],
          positions: const [],
          style: style,
          indicators: indicators,
          interval: interval,
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
  testWidgets('studies are painted in a translucent layer only below full opacity', (tester) async {
    final chart = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ChartPainter);
    const ema = [ChartEma(period: 5, color: Colors.blue)];
    final layer = paints..something((method, _) => method == #saveLayer);

    await _pumpChart(tester, ema);
    expect(chart, isNot(layer));

    await _pumpChart(tester, ema, style: const ChartStyle(studyOpacity: 0.4));
    expect(chart, layer);
  });

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
      ChartPeriodLevels(
        period: ChartLevelPeriod.day,
        previousHighColor: Colors.green,
        previousLowColor: Colors.red,
        openColor: Colors.grey,
        highColor: Colors.blue,
        lowColor: Colors.orange,
      ),
      ChartSessions(asiaColor: Colors.amber, londonColor: Colors.blue, newYorkColor: Colors.purple),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('day levels and session boxes paint with their labels over a week of hourly candles', (tester) async {
    const hour = Duration.millisecondsPerHour;
    final start =
        (DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay - 7) * Duration.millisecondsPerDay;
    await _pumpChart(
      tester,
      const [
        ChartPeriodLevels(
          period: ChartLevelPeriod.day,
          previousHighColor: Colors.green,
          previousLowColor: Colors.red,
          openColor: Colors.grey,
          highColor: Colors.blue,
          lowColor: Colors.orange,
          previousHighLabel: 'PDH',
          previousLowLabel: 'PDL',
          openLabel: 'DO',
          highLabel: 'DH',
          lowLabel: 'DL',
        ),
        ChartSessions(
          asiaColor: Colors.amber,
          londonColor: Colors.blue,
          newYorkColor: Colors.purple,
          asiaLabel: 'Asia',
          londonLabel: 'London',
          newYorkLabel: 'New York',
        ),
      ],
      candles: [
        for (var i = 0; i < 7 * 24; i++)
          ChartCandle(
            timestamp: start + i * hour,
            endTimestamp: start + (i + 1) * hour,
            open: 100.0 + i % 24,
            high: 102.0 + i % 24,
            low: 99.0 + i % 24,
            close: 101.0 + i % 24,
            volume: 1,
          ),
      ],
      interval: const Duration(hours: 1),
    );
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
              ChartAtr(color: Colors.orange),
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
    expect(transform.panes, hasLength(5));
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

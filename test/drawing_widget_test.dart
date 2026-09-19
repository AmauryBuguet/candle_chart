import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart/trading_chart.dart';

final _start = DateTime.now().millisecondsSinceEpoch - 40 * 60000;

List<ChartCandle> _candles() => [
  for (var i = 0; i < 40; i++)
    ChartCandle(
      timestamp: _start + i * 60000,
      endTimestamp: _start + (i + 1) * 60000,
      open: 100.0 + i,
      high: 102.0 + i,
      low: 99.0 + i,
      close: 101.0 + i,
      volume: 1,
    ),
];

List<ChartDrawing> _everyKind() {
  final a = Coordinates(timestamp: _start + 5 * 60000, price: 100);
  final b = Coordinates(timestamp: _start + 30 * 60000, price: 130);
  final c = Coordinates(timestamp: _start + 20 * 60000, price: 90);
  return [
    ChartTrendLine(id: 1, points: [a, b], color: Colors.blue, selected: true),
    ChartRay(id: 2, points: [a, b], color: Colors.blue, lineStyle: ChartLineStyle.dashed),
    ChartExtendedLine(id: 3, points: [a, b], color: Colors.blue, lineStyle: ChartLineStyle.dotted),
    ChartHorizontalLine(id: 4, points: [a], color: Colors.blue),
    ChartHorizontalRay(id: 5, points: [a], color: Colors.blue),
    ChartVerticalLine(id: 6, points: [a], color: Colors.blue),
    ChartRectangle(id: 7, points: [a, b], color: Colors.blue),
    ChartParallelChannel(id: 8, points: [a, b, c], color: Colors.blue),
    ChartFibRetracement(id: 9, points: [a, b], color: Colors.blue),
    ChartText(id: 10, points: [c], color: Colors.blue, text: 'note', selected: false),
    ChartMeasure(id: 11, points: [a, b], color: Colors.blue),
  ];
}

Future<void> _pump(
  WidgetTester tester, {
  List<ChartDrawing> drawings = const [],
  ChartStyle style = const ChartStyle(),
  void Function(Object? id)? onSelected,
  void Function(Object id)? onDeleted,
}) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TradingChart(
          candles: _candles(),
          lines: const [],
          orderLines: const [],
          positions: const [],
          style: style,
          drawings: drawings,
          interval: const Duration(minutes: 1),
          viewConfig: const ChartViewConfig(),
          viewResetKey: 'BTC',
          formatPrice: (price) => price.toStringAsFixed(1),
          onPointerDownInChart: (_, _, _, _) {},
          onPointerDownOutsideChart: () {},
          onDragUpdate: (_, _, _) => false,
          onDragEnd: () async {},
          onDrawingSelected: onSelected,
          onDrawingDeleted: onDeleted,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every kind of drawing paints, the selected one with handles', (tester) async {
    await _pump(tester, drawings: _everyKind());
    expect(tester.takeException(), isNull);
  });

  testWidgets('the line chart type paints', (tester) async {
    await _pump(tester, style: const ChartStyle(chartType: ChartType.line));
    expect(tester.takeException(), isNull);
  });

  testWidgets('after a click the chart answers Escape and Delete for the selected drawing', (tester) async {
    final selected = <Object?>[];
    final deleted = <Object>[];
    await _pump(tester, drawings: _everyKind(), onSelected: selected.add, onDeleted: deleted.add);

    // A click on empty chart takes focus; it also lands on no drawing, so
    // the selection is dropped once.
    await tester.tapAt(const Offset(1200, 40));
    await tester.pump();
    expect(selected, [null]);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(deleted, [1]);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(selected, [null, null]);
    // The tap armed the double-tap timer; let it lapse.
    await tester.pumpAndSettle();
  });
}

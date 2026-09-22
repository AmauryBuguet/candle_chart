import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart/src/painter/chart_painter.dart';
import 'package:trading_chart/trading_chart.dart';

final _start = (DateTime.now().millisecondsSinceEpoch ~/ 60000 - 40) * 60000;

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
    ChartFibExtension(id: 12, points: [a, b, c], color: Colors.blue),
  ];
}

Future<void> _pump(
  WidgetTester tester, {
  List<ChartDrawing> drawings = const [],
  ChartStyle style = const ChartStyle(),
  void Function(Object? id)? onSelected,
  void Function(Object id)? onDeleted,
  VoidCallback? onCancelled,
  TradingChartController? controller,
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
          onDrawingCancelled: onCancelled,
          controller: controller,
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

  testWidgets('the mouse cursor says what a drawing under it would do', (tester) async {
    final controller = TradingChartController();
    final a = Coordinates(timestamp: _start + 5 * 60000, price: 100);
    final b = Coordinates(timestamp: _start + 30 * 60000, price: 130);
    await _pump(
      tester,
      controller: controller,
      drawings: [
        ChartHorizontalLine(id: 1, points: [a], color: Colors.blue, selected: true),
        ChartTrendLine(id: 2, points: [a, b], color: Colors.blue),
      ],
    );
    final transform = controller.transform!;
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    MouseRegion region() => tester.widget<MouseRegion>(
      find.descendant(of: find.byType(TradingChart), matching: find.byType(MouseRegion)).first,
    );

    await gesture.moveTo(Offset(transform.xForTime(_start + 15 * 60000), transform.yForPrice(100)));
    await tester.pump();
    expect(region().cursor, SystemMouseCursors.resizeUpDown);

    await gesture.moveTo(Offset(transform.xForTime(_start + 20 * 60000), transform.yForPrice(118)));
    await tester.pump();
    expect(region().cursor, SystemMouseCursors.click);

    await gesture.moveTo(Offset(transform.xForTime(_start + 20 * 60000), transform.yForPrice(135)));
    await tester.pump();
    expect(region().cursor, MouseCursor.defer);
  });

  testWidgets('the line chart type paints', (tester) async {
    await _pump(tester, style: const ChartStyle(chartType: ChartType.line));
    expect(tester.takeException(), isNull);
  });

  testWidgets('after a click the chart answers Escape and Delete for the selected drawing', (tester) async {
    final selected = <Object?>[];
    final deleted = <Object>[];
    var cancelled = 0;
    await _pump(
      tester,
      drawings: _everyKind(),
      onSelected: selected.add,
      onDeleted: deleted.add,
      onCancelled: () => cancelled++,
    );

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
    expect(cancelled, 1);
    // The tap armed the double-tap timer; let it lapse.
    await tester.pumpAndSettle();
  });

  testWidgets('picking a tool up gives the chart focus, so Escape drops it before any click', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tool = ValueNotifier<ChartDrawingTool?>(null);
    addTearDown(tool.dispose);
    var cancelled = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: tool,
            builder: (_, active, _) => TradingChart(
              candles: _candles(),
              lines: const [],
              orderLines: const [],
              positions: const [],
              style: const ChartStyle(),
              activeTool: active,
              interval: const Duration(minutes: 1),
              viewConfig: const ChartViewConfig(),
              viewResetKey: 'BTC',
              formatPrice: (price) => price.toStringAsFixed(1),
              onPointerDownInChart: (_, _, _, _) {},
              onPointerDownOutsideChart: () {},
              onDragUpdate: (_, _, _) => false,
              onDragEnd: () async {},
              onDrawingCancelled: () {
                cancelled++;
                tool.value = null;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(cancelled, 0);

    tool.value = ChartDrawingTool.trendLine;
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(cancelled, 1);
    expect(tool.value, isNull);
  });

  testWidgets('a right click drops the half-placed drawing and lets the host put the tool down', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: _PlacingHost(onSelected: (_) {})),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(300, 300));
    await tester.pump();
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await gesture.down(const Offset(600, 400));
    await gesture.up();
    await tester.pump();
    // The next click lands on nothing rather than closing the first line.
    await tester.tapAt(const Offset(700, 500));
    await tester.pump();
    final chart = tester.widget<TradingChart>(find.byType(TradingChart));
    expect(chart.drawings, isEmpty);
    expect(chart.activeTool, isNull);
    await tester.pumpAndSettle();
  });

  testWidgets('on a phone the tool is aimed with a cursor: swipes move it, taps place under it', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: _PlacingHost(onSelected: (_) {})),
      ),
    );
    await tester.pumpAndSettle();
    final chart = tester.getRect(find.byType(TradingChart));

    ChartPainter painter() =>
        tester
                .widget<CustomPaint>(find.descendant(of: find.byType(TradingChart), matching: find.byType(CustomPaint)))
                .painter!
            as ChartPainter;
    expect(painter().crosshairArmed, isTrue);
    // The aim starts in the middle; the crosshair sits on the candle grid there.
    expect(painter().crosshairPosition!.dy, closeTo(painter().layout.priceRect.center.dy, 0.01));
    expect(painter().crosshairPosition!.dx, closeTo(painter().layout.priceRect.center.dx, 5));

    await tester.tapAt(chart.topLeft + const Offset(20, 20));
    await tester.pump();
    expect(tester.widget<TradingChart>(find.byType(TradingChart)).drawings, isEmpty);
    await tester.dragFrom(chart.bottomRight - const Offset(40, 40), const Offset(-100, 0));
    await tester.pump();
    await tester.tapAt(chart.topLeft + const Offset(20, 20));
    await tester.pump();

    final drawing = tester.widget<TradingChart>(find.byType(TradingChart)).drawings.single;
    final rect = painter().layout.priceRect;
    final projection = painter().projectionFor(rect);
    final points = [for (final p in drawing.points) projection.offsetOf(p)];
    // Points land on the candle grid, so up to half a candle from the aim.
    final halfBar = (projection.xForTime(_start + 60000) - projection.xForTime(_start)) / 2;
    expect(painter().crosshairArmed, isFalse);
    expect(points[0].dx, closeTo(rect.center.dx, halfBar));
    expect(points[1].dx, closeTo(rect.center.dx - 100, halfBar));
    await tester.pumpAndSettle();
  });

  testWidgets('Shift held on the second click levels the line with the first point', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: _PlacingHost(onSelected: (_) {})),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(300, 300));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(const Offset(600, 340));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    final points = tester.widget<TradingChart>(find.byType(TradingChart)).drawings.single.points;
    expect(points[1].price, points[0].price);
    expect(points[1].timestamp, greaterThan(points[0].timestamp));
    await tester.pumpAndSettle();
  });

  testWidgets('a host that keeps the new drawing selected and drops the tool at once is left alone', (tester) async {
    final selected = <Object?>[];
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: _PlacingHost(onSelected: selected.add)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(300, 300));
    await tester.pump();
    await tester.tapAt(const Offset(600, 400));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(selected, isEmpty);
    final chart = tester.widget<TradingChart>(find.byType(TradingChart));
    expect(chart.activeTool, isNull);
    expect(chart.drawings.single.selected, isTrue);
    await tester.pumpAndSettle();
  });
}

class _PlacingHost extends StatefulWidget {
  const _PlacingHost({required this.onSelected});

  final void Function(Object? id) onSelected;

  @override
  State<_PlacingHost> createState() => _PlacingHostState();
}

class _PlacingHostState extends State<_PlacingHost> {
  ChartDrawingTool? _tool = ChartDrawingTool.trendLine;
  List<ChartDrawing> _drawings = const [];

  @override
  Widget build(BuildContext context) => TradingChart(
    candles: _candles(),
    lines: const [],
    orderLines: const [],
    positions: const [],
    style: const ChartStyle(),
    drawings: _drawings,
    activeTool: _tool,
    interval: const Duration(minutes: 1),
    viewConfig: const ChartViewConfig(),
    viewResetKey: 'BTC',
    formatPrice: (price) => price.toStringAsFixed(1),
    onPointerDownInChart: (_, _, _, _) {},
    onPointerDownOutsideChart: () {},
    onDragUpdate: (_, _, _) => false,
    onDragEnd: () async {},
    onDrawingCreated: (drawing) => setState(() {
      _drawings = [drawing.copyWith(selected: true)];
      _tool = null;
    }),
    onDrawingSelected: widget.onSelected,
    onDrawingCancelled: () => setState(() => _tool = null),
  );
}

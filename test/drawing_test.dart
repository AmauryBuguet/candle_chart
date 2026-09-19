import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart/src/internal/chart_controller.dart';
import 'package:trading_chart/src/internal/drawing_geometry.dart';
import 'package:trading_chart/trading_chart.dart';

final _start = DateTime.now().millisecondsSinceEpoch - 40 * 60000;

List<ChartCandle> _candles() => [
  for (var i = 0; i < 40; i++)
    ChartCandle(
      timestamp: _start + i * 60000,
      endTimestamp: _start + (i + 1) * 60000,
      open: 100,
      high: 110,
      low: 90,
      close: 105,
      volume: 1,
    ),
];

ChartController _controller({List<ChartDrawing> drawings = const [], ChartDrawingTool? tool, bool magnet = false}) =>
    ChartController(
      interval: const Duration(minutes: 1),
      viewConfig: const ChartViewConfig(),
      candles: _candles(),
      viewResetKey: 'BTC',
      formatPrice: (price) => price.toStringAsFixed(1),
      labelStyle: const ChartLabelStyle(),
      indicators: const [],
      colors: const ChartColors(),
    )
      ..drawings = drawings
      ..activeTool = tool
      ..magnet = magnet;

const _size = Size(600, 400);

DrawingProjection _projection() => DrawingProjection(
  rect: const Rect.fromLTRB(0, 0, 100, 100),
  xForTime: (t) => t.toDouble(),
  yForPrice: (p) => 100 - p,
  timeForX: (x) => x.round(),
  priceForY: (y) => 100 - y,
);

void main() {
  group('geometry', () {
    final projection = _projection();
    const points = [Coordinates(timestamp: 10, price: 90), Coordinates(timestamp: 50, price: 50)];
    const line = ChartTrendLine(id: 'a', points: points, color: Colors.blue);

    test('a trend line is hit near its stroke and missed away from it', () {
      // From (10, 10) to (50, 50) on screen.
      expect(hitTestDrawing(line, const Offset(30, 32), projection, handles: false), isNotNull);
      expect(hitTestDrawing(line, const Offset(30, 45), projection, handles: false), isNull);
    });

    test('an anchor is reported when handles are live', () {
      expect(hitTestDrawing(line, const Offset(52, 48), projection, handles: true)?.anchor, 1);
      expect(hitTestDrawing(line, const Offset(52, 48), projection, handles: false)?.anchor, isNull);
    });

    test('a ray runs on past its second point, a segment stops', () {
      const ray = ChartRay(id: 'r', points: points, color: Colors.blue);
      expect(hitTestDrawing(ray, const Offset(80, 80), projection, handles: false), isNotNull);
      expect(hitTestDrawing(line, const Offset(80, 80), projection, handles: false), isNull);
    });

    test('a rectangle is hit inside, a hidden one never', () {
      const box = ChartRectangle(id: 'b', points: points, color: Colors.blue);
      expect(hitTestDrawing(box, const Offset(30, 20), projection, handles: false), isNotNull);
      expect(hitTestDrawing(box.copyWith(hidden: true), const Offset(30, 20), projection, handles: false), isNull);
    });

    test('a horizontal line spans the pane at its price', () {
      const h = ChartHorizontalLine(id: 'h', points: [Coordinates(timestamp: 10, price: 40)], color: Colors.blue);
      expect(drawingSegments(h, projection).single, (const Offset(0, 60), const Offset(100, 60)));
    });

    test('fibonacci levels sit between the two prices', () {
      const fib = ChartFibRetracement(id: 'f', points: points, color: Colors.blue);
      final segments = drawingSegments(fib, projection);
      expect(segments, hasLength(fibLevels.length));
      expect(segments.first.$1.dy, 10);
      expect(segments.last.$1.dy, 50);
      expect(segments[3].$1.dy, 30);
    });
  });

  test('a drawing survives the round trip through JSON, id as a string', () {
    const text = ChartText(
      id: 42,
      points: [Coordinates(timestamp: 5, price: 1.5)],
      color: Color(0xFF123456),
      text: 'note',
      width: 2,
      lineStyle: ChartLineStyle.dashed,
      locked: true,
      hidden: true,
      selected: true,
    );
    final back = ChartDrawing.fromJson(text.toJson());
    expect(back.id, '42');
    expect(back, isA<ChartText>().having((t) => t.text, 'text', 'note'));
    expect(back.points, text.points);
    expect(back.color, text.color);
    expect(back.width, 2);
    expect(back.lineStyle, ChartLineStyle.dashed);
    expect(back.locked, isTrue);
    expect(back.hidden, isTrue);
    // Selection is not kept: it is what the user is doing, not what they drew.
    expect(back.selected, isFalse);
  });

  group('controller', () {
    test('a tool places its points on taps and hands the drawing over', () {
      ChartDrawing? created;
      final controller = _controller(tool: ChartDrawingTool.trendLine)..onDrawingCreated = (d) => created = d;
      final rect = controller.layoutFor(_size).priceRect;

      void tap(Offset at) => controller.onPointerDown(
        PointerDownEvent(position: at, kind: PointerDeviceKind.mouse),
        _size,
        false,
        onPointerDownInChart: (_, _, _, _) => fail('the tool takes the tap'),
        onPointerDownOutsideChart: () {},
      );

      tap(rect.center - const Offset(100, 0));
      expect(created, isNull);
      expect(controller.placingFor(_size), isA<ChartTrendLine>());
      tap(rect.center + const Offset(100, 0));
      expect(created, isA<ChartTrendLine>());
      expect(created!.points[0].timestamp, lessThan(created!.points[1].timestamp));
      expect(controller.placingFor(_size), isNull);
    });

    test('with the magnet on, a point near a close lands exactly on it', () {
      ChartDrawing? created;
      final controller = _controller(tool: ChartDrawingTool.horizontalLine, magnet: true)
        ..onDrawingCreated = (d) => created = d;
      final projection = controller.projectionFor(_size);
      final candle = _candles()[20];
      final near = Offset(projection.xForTime(candle.timestamp + 30000), projection.yForPrice(105) + 3);

      controller.onPointerDown(
        PointerDownEvent(position: near, kind: PointerDeviceKind.mouse),
        _size,
        false,
        onPointerDownInChart: (_, _, _, _) {},
        onPointerDownOutsideChart: () {},
      );
      expect(created!.points.single, Coordinates(timestamp: candle.timestamp, price: 105));
    });

    test('tapping a drawing selects it, tapping nothing deselects, dragging moves it', () {
      final ids = <Object?>[];
      ChartDrawing? changed;
      final line = ChartTrendLine(
        id: 'a',
        points: [Coordinates(timestamp: _start + 5 * 60000, price: 95), Coordinates(timestamp: _start + 30 * 60000, price: 105)],
        color: Colors.blue,
      );
      final controller = _controller(drawings: [line])
        ..onDrawingSelected = ids.add
        ..onDrawingChanged = (d) => changed = d;
      final projection = controller.projectionFor(_size);
      final middle = Offset.lerp(projection.offsetOf(line.points[0]), projection.offsetOf(line.points[1]), 0.5)!;

      controller.onPointerDown(
        PointerDownEvent(position: middle, kind: PointerDeviceKind.mouse),
        _size,
        false,
        onPointerDownInChart: (_, _, _, _) => fail('the drawing takes the tap'),
        onPointerDownOutsideChart: () {},
      );
      expect(ids, ['a']);

      controller.onPointerMove(
        PointerMoveEvent(position: middle + const Offset(0, 20), delta: const Offset(0, 20)),
        _size,
        onDragUpdate: (_, _, _) => fail('the drawing takes the drag'),
      );
      expect(changed, isNotNull);
      expect(changed!.points[0].price, lessThan(95));
      expect(changed!.points[0].timestamp, line.points[0].timestamp);
      controller.endDrawingDrag();

      controller.drawings = [line.copyWith(selected: true)];
      var hostTapped = false;
      controller.onPointerDown(
        PointerDownEvent(position: projection.rect.topLeft + const Offset(20, 20), kind: PointerDeviceKind.mouse),
        _size,
        false,
        onPointerDownInChart: (_, _, _, _) => hostTapped = true,
        onPointerDownOutsideChart: () {},
      );
      expect(ids, ['a', null]);
      expect(hostTapped, isTrue);
    });

    test('a locked drawing is selected but never moved', () {
      ChartDrawing? changed;
      final line = ChartHorizontalLine(
        id: 'a',
        points: [Coordinates(timestamp: _start, price: 100)],
        color: Colors.blue,
        locked: true,
      );
      final controller = _controller(drawings: [line])..onDrawingChanged = (d) => changed = d;
      final y = controller.projectionFor(_size).yForPrice(100);
      controller.onPointerDown(
        PointerDownEvent(position: Offset(100, y), kind: PointerDeviceKind.mouse),
        _size,
        false,
        onPointerDownInChart: (_, _, _, _) {},
        onPointerDownOutsideChart: () {},
      );
      controller.onPointerMove(
        PointerMoveEvent(position: Offset(100, y + 10), delta: const Offset(0, 10)),
        _size,
        onDragUpdate: (_, _, _) => false,
      );
      expect(changed, isNull);
    });
  });
}

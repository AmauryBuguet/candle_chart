import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart/src/internal/chart_controller.dart';
import 'package:trading_chart/src/internal/drawing_geometry.dart';
import 'package:trading_chart/trading_chart.dart';

/// Candles sit on the minute grid, as an exchange's do.
final _start = (DateTime.now().millisecondsSinceEpoch ~/ 60000 - 40) * 60000;

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

/// Half a candle's width on screen: the crosshair aligns on the candle grid,
/// so it may sit that far from the pointer.
double _halfBar(ChartController controller) {
  final projection = controller.projectionFor(_size);
  return (projection.xForTime(_start + 60000) - projection.xForTime(_start)) / 2;
}

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

    test('a finger may miss a stroke by more than a mouse', () {
      expect(hitTestDrawing(line, const Offset(30, 42), projection, handles: false), isNull);
      expect(
        hitTestDrawing(line, const Offset(30, 42), projection, handles: false, tolerance: DrawingHitTolerance.touch),
        isNotNull,
      );
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

    test('a rectangle is hit on its edges, not inside, and a hidden one never', () {
      // Its corners are (10, 10) and (50, 50) on screen.
      const box = ChartRectangle(id: 'b', points: points, color: Colors.blue);
      expect(hitTestDrawing(box, const Offset(30, 12), projection, handles: false), isNotNull);
      expect(hitTestDrawing(box, const Offset(30, 30), projection, handles: false), isNull);
      expect(hitTestDrawing(box.copyWith(hidden: true), const Offset(30, 12), projection, handles: false), isNull);
    });

    test('a rectangle has a handle on each corner and side; the derived corners move both points', () {
      const box = ChartRectangle(id: 'b', points: points, color: Colors.blue);
      expect(drawingAnchors(box, projection), [
        const Offset(10, 10),
        const Offset(50, 50),
        const Offset(10, 50),
        const Offset(50, 10),
        const Offset(10, 30),
        const Offset(50, 30),
        const Offset(30, 10),
        const Offset(30, 50),
      ]);
      expect(hitTestDrawing(box, const Offset(11, 49), projection, handles: true)?.anchor, 2);
      expect(hitTestDrawing(box, const Offset(49, 11), projection, handles: true)?.anchor, 3);
      expect(movedAnchor(box, 2, const Coordinates(timestamp: 20, price: 40)), [
        const Coordinates(timestamp: 20, price: 90),
        const Coordinates(timestamp: 50, price: 40),
      ]);
      expect(movedAnchor(box, 3, const Coordinates(timestamp: 60, price: 80)), [
        const Coordinates(timestamp: 10, price: 80),
        const Coordinates(timestamp: 60, price: 50),
      ]);
      expect(movedAnchor(box, 0, const Coordinates(timestamp: 5, price: 95)), [
        const Coordinates(timestamp: 5, price: 95),
        points[1],
      ]);
    });

    test('a rectangle\'s side handle moves that side alone', () {
      const box = ChartRectangle(id: 'b', points: points, color: Colors.blue);
      const to = Coordinates(timestamp: 0, price: 99);
      expect(hitTestDrawing(box, const Offset(11, 31), projection, handles: true)?.anchor, 4);
      expect(movedAnchor(box, 4, to), [const Coordinates(timestamp: 0, price: 90), points[1]]);
      expect(movedAnchor(box, 5, to), [points[0], const Coordinates(timestamp: 0, price: 50)]);
      expect(movedAnchor(box, 6, to), [const Coordinates(timestamp: 10, price: 99), points[1]]);
      expect(movedAnchor(box, 7, to), [points[0], const Coordinates(timestamp: 50, price: 99)]);
      expect(handleAxis(box, 4), DrawingHandleAxis.horizontal);
      expect(handleAxis(box, 7), DrawingHandleAxis.vertical);
      expect(handleAxis(box, 0), DrawingHandleAxis.free);
    });

    test('a retracement has a handle mid-way along its 0 line that moves it in price only', () {
      const fib = ChartFibRetracement(id: 'f', points: points, color: Colors.blue);
      expect(drawingAnchors(fib, projection), [const Offset(10, 10), const Offset(50, 50), const Offset(30, 50)]);
      expect(movedAnchor(fib, 2, const Coordinates(timestamp: 99, price: 30)), [
        points[0],
        const Coordinates(timestamp: 50, price: 30),
      ]);
      expect(handleAxis(fib, 2), DrawingHandleAxis.vertical);
    });

    test('a horizontal line keeps its handle at the given time, a vertical one at the given price', () {
      const spot = Coordinates(timestamp: 70, price: 20);
      const horizontal = ChartHorizontalLine(
        id: 'h',
        points: [Coordinates(timestamp: 10, price: 60)],
        color: Colors.blue,
      );
      const vertical = ChartVerticalLine(id: 'v', points: [Coordinates(timestamp: 10, price: 60)], color: Colors.blue);
      expect(drawingAnchors(horizontal, projection, handleAt: spot), [const Offset(70, 40)]);
      expect(drawingAnchors(vertical, projection, handleAt: spot), [const Offset(10, 80)]);
      expect(drawingAnchors(horizontal, projection), [const Offset(10, 40)]);
      expect(hitTestDrawing(horizontal, const Offset(71, 41), projection, handles: true, handleAt: spot)?.anchor, 0);
      const to = Coordinates(timestamp: 33, price: 44);
      expect(movedAnchor(horizontal, 0, to), [const Coordinates(timestamp: 10, price: 44)]);
      expect(movedAnchor(vertical, 0, to), [const Coordinates(timestamp: 33, price: 60)]);
    });

    test('a channel is a rectangle: the third point sets only its width, and its handle sits mid-way', () {
      // The first line runs from (10, 10) to (50, 50); the third point is at
      // (20, 40), 10√2 straight across from it and 10√2 along it.
      const channel = ChartParallelChannel(
        id: 'c',
        points: [...points, Coordinates(timestamp: 20, price: 60)],
        color: Colors.blue,
      );
      final segments = drawingSegments(channel, projection);
      expect(segments[0], (const Offset(10, 10), const Offset(50, 50)));
      expect(segments[1].$1.dx, closeTo(0, 1e-9));
      expect(segments[1].$1.dy, closeTo(20, 1e-9));
      expect(segments[1].$2.dx, closeTo(40, 1e-9));
      expect(segments[1].$2.dy, closeTo(60, 1e-9));
      final handle = drawingAnchors(channel, projection)[2];
      expect(handle.dx, closeTo(20, 1e-9));
      expect(handle.dy, closeTo(40, 1e-9));

      // Slid along the line, the third point changes nothing but the width.
      final slid = channel.copyWith(points: [...points, const Coordinates(timestamp: 30, price: 60)]);
      final second = drawingSegments(slid, projection)[1];
      expect(second.$1.dx, closeTo(5, 1e-9));
      expect(second.$1.dy, closeTo(15, 1e-9));
      expect(second.$2.dx, closeTo(45, 1e-9));
      expect(second.$2.dy, closeTo(55, 1e-9));
    });

    test('a polyline joins its points in order, each a handle', () {
      const line = ChartPolyline(
        id: 1,
        points: [
          Coordinates(timestamp: 10, price: 10),
          Coordinates(timestamp: 50, price: 50),
          Coordinates(timestamp: 90, price: 20),
        ],
        color: Color(0xFF000000),
      );
      final p = _projection();
      expect(drawingSegments(line, p), [
        (const Offset(10, 90), const Offset(50, 50)),
        (const Offset(50, 50), const Offset(90, 80)),
      ]);
      expect(hitTestDrawing(line, const Offset(70, 65), p, handles: false), isNotNull);
      expect(hitTestDrawing(line, const Offset(10, 50), p, handles: false), isNull);
      expect(hitTestDrawing(line, const Offset(90, 80), p, handles: true)!.anchor, 2);
      expect(
        movedAnchor(line, 1, const Coordinates(timestamp: 60, price: 40))[1],
        const Coordinates(timestamp: 60, price: 40),
      );
      expect(ChartDrawing.fromJson(line.toJson()).points, line.points);
    });

    test('a horizontal line spans the pane at its price', () {
      const h = ChartHorizontalLine(
        id: 'h',
        points: [Coordinates(timestamp: 10, price: 40)],
        color: Colors.blue,
      );
      expect(drawingSegments(h, projection).single, (const Offset(0, 60), const Offset(100, 60)));
    });

    test('fibonacci levels run from 1 on the first point to 0 on the second', () {
      const fib = ChartFibRetracement(
        id: 'f',
        points: points,
        color: Colors.blue,
      );
      final lines = fibLevelLines(fib, projection);
      expect(drawingSegments(fib, projection), isEmpty);
      expect(lines, hasLength(ChartFibRetracement.defaultLevels.length));
      expect(lines.first.$3.ratio, 0);
      expect(lines.first.$1.dy, 50);
      expect(lines.last.$1.dy, 10);
      expect(lines[3].$1.dy, 30);
      expect(fibPrice(points, 1), 90);
      expect(fibPrice(points, 0), 50);
    });

    test('a new fibonacci drawing colours its levels by ratio, the same in both kinds', () {
      const colors = [ChartFibLevel(0.618, color: Color(0xFF00FF00)), ChartFibLevel(1, color: Color(0xFF0000FF))];
      final retracement =
          ChartDrawingTool.fibRetracement.create(id: 'r', points: points, color: Colors.blue, fibLevels: colors)
              as ChartFibRetracement;
      final extension =
          ChartDrawingTool.fibExtension.create(
                id: 'x',
                points: [...points, const Coordinates(timestamp: 30, price: 70)],
                color: Colors.blue,
                fibLevels: colors,
              )
              as ChartFibExtension;
      Color? colorOf(List<ChartFibLevel> levels, double ratio) => levels.firstWhere((l) => l.ratio == ratio).color;
      expect(colorOf(retracement.levels, 0.618), const Color(0xFF00FF00));
      expect(colorOf(retracement.levels, 1), const Color(0xFF0000FF));
      expect(colorOf(extension.levels, 1), const Color(0xFF0000FF));
      // Ratios with no colour of their own follow the drawing's.
      expect(colorOf(retracement.levels, 0.5), isNull);
    });

    test('a hidden fibonacci level is neither drawn nor hit; its colour and visibility survive JSON', () {
      final levels = [...ChartFibRetracement.defaultLevels];
      levels[3] = levels[3].copyWith(visible: false);
      levels[4] = levels[4].copyWith(color: const Color(0xFFFF0000));
      final fib = ChartFibRetracement(id: 'f', points: points, color: Colors.blue, levels: levels);
      final lines = fibLevelLines(fib, projection);
      expect(lines.map((l) => l.$3.ratio), isNot(contains(0.5)));
      expect(lines, hasLength(levels.length - 1));
      // The 0.5 level sits at y 30.
      const exact = DrawingHitTolerance(stroke: 1, handle: 1);
      expect(hitTestDrawing(fib, const Offset(30, 30), projection, handles: false, tolerance: exact), isNull);
      expect(hitTestDrawing(fib, const Offset(30, 50), projection, handles: false, tolerance: exact), isNotNull);

      final back = ChartDrawing.fromJson(fib.toJson()) as ChartFibRetracement;
      expect(back.levels, levels);
      expect(back.levels[4].color, const Color(0xFFFF0000));
      // A drawing saved before levels were kept reads back with the defaults.
      final legacy = fib.toJson()..remove('levels');
      expect((ChartDrawing.fromJson(legacy) as ChartFibRetracement).levels, ChartFibRetracement.defaultLevels);
    });

    test('fibonacci extension projects the first move from the third point, levels running to the right edge', () {
      // A move of -40 from 90 to 50, projected from 70: 0 sits at 70, 1 at 30.
      const fib = ChartFibExtension(
        id: 'x',
        points: [...points, Coordinates(timestamp: 30, price: 70)],
        color: Colors.blue,
      );
      expect(fibExtensionPrice(fib.points, 0), 70);
      expect(fibExtensionPrice(fib.points, 1), 30);
      expect(fibExtensionPrice(fib.points, 1.618), closeTo(5.28, 1e-9));
      final segments = drawingSegments(fib, projection);
      final lines = fibLevelLines(fib, projection);
      expect(segments, [(const Offset(10, 10), const Offset(50, 50)), (const Offset(50, 50), const Offset(30, 30))]);
      expect(lines, hasLength(ChartFibExtension.defaultLevels.length));
      expect((lines[0].$1, lines[0].$2), (const Offset(30, 30), const Offset(100, 30)));
      expect(lines[1].$1.dy, 70);
      expect(drawingAnchors(fib, projection), hasLength(3));
      expect(hitTestDrawing(fib, const Offset(80, 31), projection, handles: false), isNotNull);
      expect(hitTestDrawing(fib, const Offset(5, 31), projection, handles: false), isNull);
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

    test("the host's style is on the preview and on the drawing created", () {
      ChartDrawing? created;
      final controller = _controller(tool: ChartDrawingTool.trendLine)
        ..onDrawingCreated = ((d) => created = d)
        ..styleDrawing = ((d) => d.copyWith(width: 3, lineStyle: ChartLineStyle.dashed));
      final rect = controller.layoutFor(_size).priceRect;

      void click(Offset at) => controller.onPointerDown(
        PointerDownEvent(position: at, kind: PointerDeviceKind.mouse),
        _size,
        false,
        onPointerDownInChart: (_, _, _, _) => fail('the tool takes the click'),
        onPointerDownOutsideChart: () {},
      );

      click(rect.center - const Offset(100, 0));
      expect(controller.placingFor(_size)!.width, 3);
      click(rect.center + const Offset(100, 0));
      expect(created!.width, 3);
      expect(created!.lineStyle, ChartLineStyle.dashed);
    });

    test('a polyline takes points until one lands on the last, or it is finished', () {
      final created = <ChartDrawing>[];
      final controller = _controller(tool: ChartDrawingTool.polyline)..onDrawingCreated = created.add;
      final rect = controller.layoutFor(_size).priceRect;

      void click(Offset at) => controller.onPointerDown(
        PointerDownEvent(position: at, kind: PointerDeviceKind.mouse),
        _size,
        false,
        onPointerDownInChart: (_, _, _, _) => fail('the tool takes the click'),
        onPointerDownOutsideChart: () {},
      );

      // A point on the only one so far neither doubles it nor finishes.
      click(rect.center - const Offset(150, 0));
      click(rect.center - const Offset(150, 0));
      expect(controller.placingFor(_size)!.points, hasLength(2));
      click(rect.center);
      click(rect.center + const Offset(150, -50));
      expect(created, isEmpty);
      expect(controller.placingFor(_size)!.points, hasLength(4));

      click(rect.center + const Offset(152, -48));
      expect(created.single, isA<ChartPolyline>().having((d) => d.points.length, 'points', 3));
      expect(controller.placingFor(_size), isNull);

      click(rect.center - const Offset(100, 0));
      controller.finishDrawing();
      expect(created, hasLength(1));
      click(rect.center);
      controller.finishDrawing();
      expect(created.last.points, hasLength(2));
    });

    test('a mouse held down after placing a point keeps aiming the next one', () {
      ChartDrawing? created;
      final controller = _controller(tool: ChartDrawingTool.rectangle)..onDrawingCreated = (d) => created = d;
      final rect = controller.layoutFor(_size).priceRect;
      final first = rect.center - const Offset(100, 50);
      final before = controller.timeAxis;

      controller.onPointerDown(
        PointerDownEvent(position: first, kind: PointerDeviceKind.mouse),
        _size,
        false,
        onPointerDownInChart: (_, _, _, _) => fail('the tool takes the click'),
        onPointerDownOutsideChart: () {},
      );
      controller.onPointerMove(
        PointerMoveEvent(position: first + const Offset(80, 40), delta: const Offset(80, 40)),
        _size,
        onDragUpdate: (_, _, _) => fail('the tool holds the drag'),
      );
      expect(controller.crosshairPosition, first + const Offset(80, 40));
      expect(controller.timeAxis, before);
      final preview = controller.placingFor(_size)!;
      final projection = controller.projectionFor(_size);
      expect(projection.offsetOf(preview.points[1]).dx, closeTo(first.dx + 80, _halfBar(controller)));
      expect(projection.offsetOf(preview.points[1]).dy, closeTo(first.dy + 40, 1));
      expect(created, isNull);

      controller.onPointerUp(PointerUpEvent(position: first + const Offset(80, 40)), _size);
      expect(created, isNull);
      controller.onPointerDown(
        PointerDownEvent(position: first + const Offset(100, 60), kind: PointerDeviceKind.mouse),
        _size,
        false,
        onPointerDownInChart: (_, _, _, _) => fail('the tool takes the click'),
        onPointerDownOutsideChart: () {},
      );
      expect(created, isA<ChartRectangle>());
    });

    test('a selected line\'s handle spot is the pane\'s middle when it was selected, kept while it stays so', () {
      final line = ChartHorizontalLine(
        id: 'h',
        points: [Coordinates(timestamp: _start, price: 100)],
        color: Colors.blue,
        selected: true,
      );
      final controller = _controller();
      expect(controller.handleSpotFor(_size), isNull);
      controller.drawings = [line];
      final projection = controller.projectionFor(_size);
      final spot = controller.handleSpotFor(_size)!;
      expect(projection.offsetOf(spot).dx, closeTo(projection.rect.center.dx, 1));
      expect(projection.offsetOf(spot).dy, closeTo(projection.rect.center.dy, 0.01));
      controller.drawings = [
        line.copyWith(points: [Coordinates(timestamp: _start, price: 104)]),
      ];
      expect(controller.handleSpotFor(_size), spot);
      controller.drawings = [line.copyWith(selected: false)];
      expect(controller.handleSpotFor(_size), isNull);
    });

    group('magnet', () {
      Coordinates place(Offset at, {double reach = 30}) {
        ChartDrawing? created;
        final controller = _controller(tool: ChartDrawingTool.horizontalLine, magnet: true)
          ..magnetReach = reach
          ..onDrawingCreated = (d) => created = d;
        controller.onPointerDown(
          PointerDownEvent(position: at, kind: PointerDeviceKind.mouse),
          _size,
          false,
          onPointerDownInChart: (_, _, _, _) {},
          onPointerDownOutsideChart: () {},
        );
        return created!.points.single;
      }

      final projection = _controller().projectionFor(_size);
      final candle = _candles()[20];

      test('a point near a close lands exactly on it', () {
        final near = Offset(projection.xForTime(candle.timestamp + 10000), projection.yForPrice(105) + 3);
        expect(place(near), Coordinates(timestamp: candle.timestamp, price: 105));
      });

      test('the nearest candle takes it, as the crosshair aligns, from either side', () {
        final y = projection.yForPrice(110) + 3;
        expect(place(Offset(projection.xForTime(candle.timestamp - 20000), y)).timestamp, candle.timestamp);
        expect(place(Offset(projection.xForTime(candle.timestamp + 20000), y)).timestamp, candle.timestamp);
      });

      test('with a tool in hand the crosshair sits where the point would land', () {
        final near = Offset(projection.xForTime(candle.timestamp + 10000), projection.yForPrice(110) + 5);
        final armed = _controller(tool: ChartDrawingTool.horizontalLine, magnet: true)..crosshairPosition = near;
        // Its own projection: the time axis is built on now, and a few
        // milliseconds between two controllers shift it.
        final landing = armed.projectionFor(_size).offsetOf(Coordinates(timestamp: candle.timestamp, price: 110));
        expect(armed.crosshairFor(_size)!.dx, closeTo(landing.dx, 0.01));
        expect(armed.crosshairFor(_size)!.dy, closeTo(landing.dy, 0.01));
        final idle = _controller(magnet: true)..crosshairPosition = near;
        expect(idle.crosshairFor(_size), near);
        // Without the magnet it still aligns on the candle in time.
        final off = _controller(tool: ChartDrawingTool.horizontalLine)..crosshairPosition = near;
        expect(off.crosshairFor(_size)!.dx, closeTo(off.projectionFor(_size).xForTime(candle.timestamp), 0.01));
        expect(off.crosshairFor(_size)!.dy, closeTo(near.dy, 0.01));
      });

      test('it reaches a level well away in price, and no further', () {
        final x = projection.xForTime(candle.timestamp);
        final within = Offset(x, projection.yForPrice(110) - 30 + 1);
        expect(place(within), Coordinates(timestamp: candle.timestamp, price: 110));
        final beyond = Offset(x, projection.yForPrice(110) - 30 - 1);
        expect(place(beyond).price, isNot(110));
      });

      test('its reach is the host\'s to set', () {
        final at = Offset(projection.xForTime(candle.timestamp), projection.yForPrice(110) + 20);
        expect(place(at), Coordinates(timestamp: candle.timestamp, price: 110));
        expect(place(at, reach: 10).price, isNot(110));
      });
    });

    group('axis lock', () {
      void click(ChartController controller, Offset at) => controller.onPointerDown(
        PointerDownEvent(position: at, kind: PointerDeviceKind.mouse),
        _size,
        false,
        onPointerDownInChart: (_, _, _, _) => fail('the tool takes the click'),
        onPointerDownOutsideChart: () {},
      );

      final candle = _candles()[10];
      final first = Coordinates(timestamp: candle.timestamp, price: 100);

      test('the second point takes the first\'s price or time, whichever is nearer on screen', () {
        for (final (by, level) in [(const Offset(120, 30), true), (const Offset(30, 120), false)]) {
          ChartDrawing? created;
          final controller = _controller(tool: ChartDrawingTool.trendLine)
            ..axisLock = true
            ..onDrawingCreated = (d) => created = d;
          final projection = controller.projectionFor(_size);
          final at = projection.offsetOf(first);
          click(controller, at);
          click(controller, at + by);
          final second = created!.points[1];
          if (level) {
            expect(second.price, first.price);
            expect(second.timestamp, greaterThan(first.timestamp));
          } else {
            expect(second.timestamp, first.timestamp);
            expect(second.price, lessThan(first.price));
          }
        }
      });

      test('the preview and the crosshair show the lock before the click', () {
        final controller = _controller(tool: ChartDrawingTool.trendLine)..axisLock = true;
        final projection = controller.projectionFor(_size);
        final at = projection.offsetOf(first);
        click(controller, at);
        controller.crosshairPosition = at + const Offset(120, 30);
        expect(controller.placingFor(_size)!.points[1].price, first.price);
        expect(controller.crosshairFor(_size)!.dy, closeTo(at.dy, 0.01));
      });

      test('a price lock holds against the magnet', () {
        ChartDrawing? created;
        final controller = _controller(tool: ChartDrawingTool.trendLine, magnet: true)
          ..axisLock = true
          ..onDrawingCreated = (d) => created = d;
        final projection = controller.projectionFor(_size);
        final at = projection.offsetOf(Coordinates(timestamp: candle.timestamp, price: 102));
        click(controller, at);
        // The close at 105 is within the magnet's reach; the lock wins.
        click(controller, Offset(at.dx + 120, projection.yForPrice(104)));
        expect(created!.points[1].price, 102);
      });

      test('the first point is free, as is a point with the lock off', () {
        for (final lock in [true, false]) {
          ChartDrawing? created;
          final controller = _controller(tool: ChartDrawingTool.trendLine)
            ..axisLock = lock
            ..onDrawingCreated = (d) => created = d;
          final projection = controller.projectionFor(_size);
          final at = projection.offsetOf(first);
          click(controller, at + const Offset(0, 10));
          click(controller, at + const Offset(120, 30));
          expect(created!.points[0].price, isNot(first.price));
          expect(created!.points[1].price, lock ? created!.points[0].price : isNot(created!.points[0].price));
        }
      });

      test('a dragged anchor locks to the point beside it', () {
        ChartDrawing? changed;
        final line = ChartTrendLine(
          id: 'a',
          points: [
            first,
            Coordinates(timestamp: _start + 30 * 60000, price: 105),
          ],
          color: Colors.blue,
          selected: true,
        );
        final controller = _controller(drawings: [line])
          ..axisLock = true
          ..onDrawingChanged = (d) => changed = d;
        final projection = controller.projectionFor(_size);
        final end = projection.offsetOf(line.points[1]);
        controller.onPointerDown(
          PointerDownEvent(position: end, kind: PointerDeviceKind.mouse),
          _size,
          false,
          onPointerDownInChart: (_, _, _, _) => fail('the anchor takes the click'),
          onPointerDownOutsideChart: () {},
        );
        controller.onPointerMove(
          PointerMoveEvent(position: end + const Offset(40, 10), delta: const Offset(40, 10)),
          _size,
          onDragUpdate: (_, _, _) => fail('the anchor takes the drag'),
        );
        expect(changed!.points[1].price, first.price);
        expect(changed!.points[1].timestamp, greaterThan(line.points[1].timestamp));
        expect(changed!.points[0], first);
      });
    });

    test('a placed point lands on the candle grid in time, magnet or not', () {
      ChartDrawing? created;
      final controller = _controller(tool: ChartDrawingTool.verticalLine)..onDrawingCreated = (d) => created = d;
      final candle = _candles()[20];
      final x = controller.projectionFor(_size).xForTime(candle.timestamp + 20000);
      controller.onPointerDown(
        PointerDownEvent(position: Offset(x, 100), kind: PointerDeviceKind.mouse),
        _size,
        false,
        onPointerDownInChart: (_, _, _, _) {},
        onPointerDownOutsideChart: () {},
      );
      expect(created!.points.single.timestamp, candle.timestamp);
    });

    test('a dragged drawing moves by whole intervals', () {
      ChartDrawing? changed;
      final line = ChartVerticalLine(
        id: 'v',
        points: [Coordinates(timestamp: _start + 10 * 60000, price: 100)],
        color: Colors.blue,
        selected: true,
      );
      final controller = _controller(drawings: [line])..onDrawingChanged = (d) => changed = d;
      final projection = controller.projectionFor(_size);
      final at = Offset(projection.xForTime(line.points[0].timestamp), 200);
      final barWidth = projection.xForTime(_start + 60000) - projection.xForTime(_start);
      controller.onPointerDown(
        PointerDownEvent(position: at, kind: PointerDeviceKind.mouse),
        _size,
        false,
        onPointerDownInChart: (_, _, _, _) => fail('the drawing takes the click'),
        onPointerDownOutsideChart: () {},
      );
      final by = Offset(barWidth * 2.3, 0);
      controller.onPointerMove(
        PointerMoveEvent(position: at + by, delta: by),
        _size,
        onDragUpdate: (_, _, _) => fail('the drawing takes the drag'),
      );
      expect(changed!.points.single.timestamp, _start + 12 * 60000);
      controller.onPointerUp(PointerUpEvent(position: at + by), _size);
    });

    test('a click selects a drawing and moves nothing; the next drag moves it; a click on nothing deselects', () {
      final ids = <Object?>[];
      ChartDrawing? changed;
      final line = ChartTrendLine(
        id: 'a',
        points: [
          Coordinates(timestamp: _start + 5 * 60000, price: 95),
          Coordinates(timestamp: _start + 30 * 60000, price: 105),
        ],
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

      final before = controller.timeAxis;
      controller.onPointerMove(
        PointerMoveEvent(position: middle + const Offset(0, 20), delta: const Offset(0, 20)),
        _size,
        onDragUpdate: (_, _, _) => fail('the click took the drag'),
      );
      expect(changed, isNull);
      expect(controller.timeAxis, before);
      controller.onPointerUp(
        PointerUpEvent(position: middle + const Offset(0, 20)),
        _size,
      );

      controller.drawings = [line.copyWith(selected: true)];
      controller.onPointerDown(
        PointerDownEvent(position: middle, kind: PointerDeviceKind.mouse),
        _size,
        false,
        onPointerDownInChart: (_, _, _, _) => fail('the drawing takes the click'),
        onPointerDownOutsideChart: () {},
      );
      controller.onPointerMove(
        PointerMoveEvent(position: middle + const Offset(0, 20), delta: const Offset(0, 20)),
        _size,
        onDragUpdate: (_, _, _) => fail('the drawing takes the drag'),
      );
      expect(changed, isNotNull);
      expect(changed!.points[0].price, lessThan(95));
      expect(changed!.points[0].timestamp, line.points[0].timestamp);
      controller.onPointerUp(
        PointerUpEvent(position: middle + const Offset(0, 20)),
        _size,
      );

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

    group('touch', () {
      final line = ChartTrendLine(
        id: 'a',
        points: [
          Coordinates(timestamp: _start + 5 * 60000, price: 95),
          Coordinates(timestamp: _start + 30 * 60000, price: 105),
        ],
        color: Colors.blue,
      );

      void down(ChartController controller, Offset at, {void Function()? onHost}) => controller.onPointerDown(
        PointerDownEvent(position: at, kind: PointerDeviceKind.touch),
        _size,
        true,
        onPointerDownInChart: (_, _, _, _) => onHost?.call(),
        onPointerDownOutsideChart: () {},
      );

      void move(ChartController controller, Offset from, Offset by) => controller.onPointerMove(
        PointerMoveEvent(position: from + by, delta: by, kind: PointerDeviceKind.touch),
        _size,
        onDragUpdate: (_, _, _) => false,
      );

      void up(ChartController controller, Offset at) => controller.onPointerUp(
        PointerUpEvent(position: at, kind: PointerDeviceKind.touch),
        _size,
      );

      void tap(ChartController controller, Offset at) {
        down(controller, at);
        up(controller, at);
      }

      test('a tap on nothing shows the crosshair; a swipe from elsewhere moves it by as much; a tap hides it', () {
        final controller = _controller();
        final rect = controller.layoutFor(_size).priceRect;
        final at = rect.center;
        final elsewhere = rect.bottomRight - const Offset(30, 30);
        final before = controller.timeAxis;

        tap(controller, at);
        expect(controller.crosshairPosition, at);

        down(controller, elsewhere);
        move(controller, elsewhere, const Offset(60, 10));
        expect(controller.crosshairPosition, at + const Offset(60, 10));
        expect(controller.timeAxis, before);
        up(controller, elsewhere + const Offset(60, 10));
        expect(controller.crosshairPosition, at + const Offset(60, 10));

        // A swipe from the axis carries it too, and it never leaves the plot.
        final axis = Offset(_size.width - 5, rect.center.dy);
        down(controller, axis);
        move(controller, axis, const Offset(-900, 0));
        up(controller, axis + const Offset(-900, 0));
        expect(controller.crosshairPosition, Offset(rect.left, at.dy + 10));

        tap(controller, axis);
        expect(controller.crosshairPosition, isNull);
        down(controller, at);
        move(controller, at, const Offset(60, 0));
        expect(controller.timeAxis, isNot(before));
      });

      test('with the crosshair up a tap on a drawing only hides it', () {
        final ids = <Object?>[];
        final controller = _controller(drawings: [line])..onDrawingSelected = ids.add;
        final projection = controller.projectionFor(_size);
        final middle = Offset.lerp(projection.offsetOf(line.points[0]), projection.offsetOf(line.points[1]), 0.5)!;
        tap(controller, controller.layoutFor(_size).priceRect.topLeft + const Offset(20, 20));
        expect(controller.crosshairPosition, isNotNull);
        tap(controller, middle);
        expect(controller.crosshairPosition, isNull);
        expect(ids, isEmpty);
        tap(controller, middle);
        expect(ids, ['a']);
      });

      test('a swipe starting on an unselected drawing pans; a tap selects it, then a swipe moves it', () {
        final ids = <Object?>[];
        ChartDrawing? changed;
        final controller = _controller(drawings: [line])
          ..onDrawingSelected = ids.add
          ..onDrawingChanged = (d) => changed = d;
        Offset middle() {
          final projection = controller.projectionFor(_size);
          return Offset.lerp(projection.offsetOf(line.points[0]), projection.offsetOf(line.points[1]), 0.5)!;
        }

        final before = controller.timeAxis;
        down(controller, middle());
        move(controller, middle(), const Offset(40, 0));
        up(controller, middle() + const Offset(40, 0));
        expect(ids, isEmpty);
        expect(changed, isNull);
        expect(controller.timeAxis, isNot(before));

        tap(controller, middle());
        expect(ids, ['a']);
        expect(controller.crosshairPosition, isNull);

        controller.drawings = [line.copyWith(selected: true)];
        final moved = controller.timeAxis;
        down(controller, middle());
        move(controller, middle(), const Offset(0, 20));
        expect(changed, isNotNull);
        expect(changed!.points[0].price, lessThan(95));
        expect(controller.timeAxis, moved);
        up(controller, middle() + const Offset(0, 20));

        // A tap on nothing with a selection only drops it; the next one
        // shows the crosshair.
        final empty = controller.layoutFor(_size).priceRect.topLeft + const Offset(20, 20);
        tap(controller, empty);
        expect(ids, ['a', null]);
        expect(controller.crosshairPosition, isNull);
        controller.drawings = [line];
        tap(controller, empty);
        expect(controller.crosshairPosition, empty);
      });

      test('with a tool in hand a tap places, a swipe pans', () {
        ChartDrawing? created;
        final controller = _controller(tool: ChartDrawingTool.horizontalLine)..onDrawingCreated = (d) => created = d;
        final rect = controller.layoutFor(_size).priceRect;
        final before = controller.timeAxis;

        var hostTold = false;
        down(controller, rect.center, onHost: () => hostTold = true);
        move(controller, rect.center, const Offset(40, 0));
        up(controller, rect.center + const Offset(40, 0));
        expect(created, isNull);
        expect(hostTold, isFalse);
        expect(controller.timeAxis, isNot(before));

        tap(controller, rect.center);
        expect(created, isA<ChartHorizontalLine>());
      });
    });

    group('cursor', () {
      ChartController aiming(ChartDrawingTool tool, {bool pinned = false}) {
        final controller = _controller(tool: pinned ? null : tool)..cursorPlacement = true;
        if (pinned) {
          controller.onPointerDown(
            const PointerDownEvent(position: Offset(300, 200), kind: PointerDeviceKind.touch),
            _size,
            true,
            onPointerDownInChart: (_, _, _, _) {},
            onPointerDownOutsideChart: () {},
          );
          controller.onPointerUp(
            const PointerUpEvent(position: Offset(300, 200), kind: PointerDeviceKind.touch),
            _size,
          );
          expect(controller.crosshairPosition, isNotNull);
          controller
            ..activeTool = tool
            ..toolChanged();
        }
        return controller;
      }

      void down(ChartController controller, Offset at) => controller.onPointerDown(
        PointerDownEvent(position: at, kind: PointerDeviceKind.touch),
        _size,
        true,
        onPointerDownInChart: (_, _, _, _) => fail('the cursor takes the touch'),
        onPointerDownOutsideChart: () {},
      );

      void move(ChartController controller, Offset from, Offset by) => controller.onPointerMove(
        PointerMoveEvent(position: from + by, delta: by, kind: PointerDeviceKind.touch),
        _size,
        onDragUpdate: (_, _, _) => false,
      );

      void up(ChartController controller, Offset at) => controller.onPointerUp(
        PointerUpEvent(position: at, kind: PointerDeviceKind.touch),
        _size,
      );

      test('a tool puts the crosshair away and aims from the middle; swipes move the aim, taps place', () {
        ChartDrawing? created;
        final controller = aiming(ChartDrawingTool.trendLine, pinned: true)..onDrawingCreated = (d) => created = d;
        final rect = controller.layoutFor(_size).priceRect;
        expect(controller.crosshairPosition, isNull);
        expect(controller.crosshairFor(_size)!.dx, closeTo(rect.center.dx, _halfBar(controller)));
        expect(controller.crosshairFor(_size)!.dy, closeTo(rect.center.dy, 0.01));

        final before = controller.timeAxis;
        down(controller, rect.bottomLeft + const Offset(10, -10));
        move(controller, rect.bottomLeft + const Offset(10, -10), const Offset(-40, 30));
        up(controller, rect.bottomLeft + const Offset(-30, 20));
        expect(controller.crosshairFor(_size)!.dx, closeTo(rect.center.dx - 40, _halfBar(controller)));
        expect(controller.crosshairFor(_size)!.dy, closeTo(rect.center.dy + 30, 0.01));
        expect(controller.timeAxis, before);

        down(controller, const Offset(50, 50));
        up(controller, const Offset(50, 50));
        expect(created, isNull);
        final first = controller.placingFor(_size)!.points.first;
        expect(controller.projectionFor(_size).offsetOf(first).dx, closeTo(rect.center.dx - 40, _halfBar(controller)));
        expect(controller.projectionFor(_size).offsetOf(first).dy, closeTo(rect.center.dy + 30, 0.01));
        expect(controller.crosshairFor(_size)!.dy, closeTo(rect.center.dy + 30, 0.01));

        down(controller, const Offset(50, 50));
        move(controller, const Offset(50, 50), const Offset(80, 0));
        up(controller, const Offset(130, 50));
        expect(controller.placingFor(_size)!.points.last.timestamp, greaterThan(first.timestamp));
        down(controller, const Offset(50, 50));
        up(controller, const Offset(50, 50));
        expect(created, isA<ChartTrendLine>());
        expect(created!.points.first, first);
      });

      test('the aim never leaves the price pane and starts over with the next tool', () {
        final controller = aiming(ChartDrawingTool.horizontalLine);
        final rect = controller.layoutFor(_size).priceRect;
        down(controller, rect.center);
        move(controller, rect.center, const Offset(-2000, 2000));
        up(controller, rect.center + const Offset(-2000, 2000));
        expect(controller.crosshairFor(_size)!.dx, closeTo(rect.left, _halfBar(controller)));
        expect(controller.crosshairFor(_size)!.dy, closeTo(rect.bottom, 0.01));
        controller
          ..activeTool = ChartDrawingTool.ray
          ..toolChanged();
        expect(controller.crosshairFor(_size)!.dx, closeTo(rect.center.dx, _halfBar(controller)));
        expect(controller.crosshairFor(_size)!.dy, closeTo(rect.center.dy, 0.01));
      });
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

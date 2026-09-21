import 'dart:math';
import 'dart:ui';

import '../models/chart_drawing.dart';
import '../models/coordinates.dart';

/// The Fibonacci retracement ratios: 1 sits on the first point's price, 0
/// on the second's.
const List<double> fibLevels = [0, 0.236, 0.382, 0.5, 0.618, 0.786, 1];

/// The price of a Fibonacci [level] between the two anchors' prices.
double fibPrice(List<Coordinates> points, double level) =>
    points[0].price + (points[1].price - points[0].price) * (1 - level);

/// The trend-based Fibonacci extension ratios: 0 sits on the third point's
/// price, 1 a whole first-to-second move above (or below) it.
const List<double> fibExtensionLevels = [0, 0.236, 0.382, 0.5, 0.618, 0.786, 1, 1.618, 2.618, 3.618, 4.236];

/// The price of a Fibonacci extension [level]: the move from the first
/// point to the second, scaled by [level], projected from the third.
double fibExtensionPrice(List<Coordinates> points, double level) =>
    points[2].price + (points[1].price - points[0].price) * level;

/// The price pane's mapping, the only thing drawing geometry needs.
class DrawingProjection {
  const DrawingProjection({
    required this.rect,
    required this.xForTime,
    required this.yForPrice,
    required this.timeForX,
    required this.priceForY,
  });

  final Rect rect;
  final double Function(int timestamp) xForTime;
  final double Function(double price) yForPrice;
  final int Function(double x) timeForX;
  final double Function(double y) priceForY;

  Offset offsetOf(Coordinates c) => Offset(xForTime(c.timestamp), yForPrice(c.price));

  Coordinates coordinatesOf(Offset o) => Coordinates(timestamp: timeForX(o.dx), price: priceForY(o.dy));
}

/// Where a pointer landed on a drawing: on one of its anchors, or on its
/// body.
class DrawingHit {
  const DrawingHit({this.anchor});

  final int? anchor;
}

/// How far a pointer may miss a stroke or an anchor by and still hit it,
/// in pixels: a mouse is precise, a finger is not.
class DrawingHitTolerance {
  const DrawingHitTolerance({required this.stroke, required this.handle});

  static const mouse = DrawingHitTolerance(stroke: 8, handle: 10);
  static const touch = DrawingHitTolerance(stroke: 16, handle: 20);

  final double stroke;
  final double handle;
}

/// The screen positions of a drawing's handles: its points, plus a
/// rectangle's two other corners; a channel's third handle sits in the
/// middle of its second line.
List<Offset> drawingAnchors(ChartDrawing drawing, DrawingProjection p) {
  final a = _pointsOf(drawing, p);
  return switch (drawing) {
    ChartRectangle() => [...a, Offset(a[0].dx, a[1].dy), Offset(a[1].dx, a[0].dy)],
    ChartParallelChannel() => [a[0], a[1], (a[0] + a[1]) / 2 + _channelOffset(a)],
    _ => a,
  };
}

List<Offset> _pointsOf(ChartDrawing drawing, DrawingProjection p) => [for (final c in drawing.points) p.offsetOf(c)];

/// The points of [drawing] once its handle [anchor] is dragged to [to]: a
/// rectangle's derived corners move the two points they are made of.
List<Coordinates> movedAnchor(ChartDrawing drawing, int anchor, Coordinates to) {
  final points = [...drawing.points];
  if (drawing is ChartRectangle && anchor >= 2) {
    final (timeOf, priceOf) = anchor == 2 ? (0, 1) : (1, 0);
    points[timeOf] = Coordinates(timestamp: to.timestamp, price: points[timeOf].price);
    points[priceOf] = Coordinates(timestamp: points[priceOf].timestamp, price: to.price);
  } else {
    points[anchor] = to;
  }
  return points;
}

/// A channel's second line: the first carried straight across to the
/// third point, which sets only the width, so the two lines are always
/// the sides of a rectangle.
(Offset, Offset) _channelSecondLine(List<Offset> a) {
  final across = _channelOffset(a);
  return (a[0] + across, a[1] + across);
}

Offset _channelOffset(List<Offset> a) {
  final along = a[1] - a[0];
  if (along.distance == 0) return a[2] - a[0];
  final normal = Offset(-along.dy, along.dx) / along.distance;
  final toThird = a[2] - (a[0] + a[1]) / 2;
  return normal * (toThird.dx * normal.dx + toThird.dy * normal.dy);
}

/// The straight strokes of a drawing, extended lines run out past the pane.
List<(Offset, Offset)> drawingSegments(ChartDrawing drawing, DrawingProjection p) {
  final a = _pointsOf(drawing, p);
  final rect = p.rect;
  final reach = (rect.width + rect.height) * 4;
  return switch (drawing) {
    ChartTrendLine() => [(a[0], a[1])],
    ChartRay() => [(a[0], _extend(a[0], a[1], reach))],
    ChartExtendedLine() => [(_extend(a[1], a[0], reach), _extend(a[0], a[1], reach))],
    ChartHorizontalLine() => [(Offset(rect.left, a[0].dy), Offset(rect.right, a[0].dy))],
    ChartHorizontalRay() => [(a[0], Offset(rect.right, a[0].dy))],
    ChartVerticalLine() => [(Offset(a[0].dx, rect.top), Offset(a[0].dx, rect.bottom))],
    ChartRectangle() || ChartMeasure() => _rectEdges(Rect.fromPoints(a[0], a[1])),
    ChartParallelChannel() => [(a[0], a[1]), _channelSecondLine(a)],
    ChartFibRetracement() => [
      for (final y in _fibYs(drawing, p)) (Offset(min(a[0].dx, a[1].dx), y), Offset(max(a[0].dx, a[1].dx), y)),
    ],
    ChartFibExtension() => [
      (a[0], a[1]),
      (a[1], a[2]),
      for (final y in _fibExtensionYs(drawing, p)) (Offset(a[2].dx, y), Offset(rect.right, y)),
    ],
    ChartText() => const [],
  };
}

/// The filled area of a drawing, if it has one.
Path? drawingArea(ChartDrawing drawing, DrawingProjection p) {
  final a = _pointsOf(drawing, p);
  return switch (drawing) {
    ChartRectangle() || ChartMeasure() => Path()..addRect(Rect.fromPoints(a[0], a[1])),
    ChartParallelChannel() => switch (_channelSecondLine(a)) {
      (final c, final d) =>
        Path()
          ..moveTo(a[0].dx, a[0].dy)
          ..lineTo(a[1].dx, a[1].dy)
          ..lineTo(d.dx, d.dy)
          ..lineTo(c.dx, c.dy)
          ..close(),
    },
    _ => null,
  };
}

Iterable<double> _fibYs(ChartFibRetracement drawing, DrawingProjection p) =>
    fibLevels.map((level) => p.yForPrice(fibPrice(drawing.points, level)));

Iterable<double> _fibExtensionYs(ChartFibExtension drawing, DrawingProjection p) =>
    fibExtensionLevels.map((level) => p.yForPrice(fibExtensionPrice(drawing.points, level)));

/// Whether [position] is on the drawing: on an anchor when [handles] are
/// live, else on a stroke — a filled area is not a handle on it.
DrawingHit? hitTestDrawing(
  ChartDrawing drawing,
  Offset position,
  DrawingProjection p, {
  required bool handles,
  DrawingHitTolerance tolerance = DrawingHitTolerance.mouse,
  Size Function(ChartText text)? textSize,
}) {
  if (drawing.hidden) return null;
  final anchors = drawingAnchors(drawing, p);
  if (handles) {
    for (var i = 0; i < anchors.length; i++) {
      if ((anchors[i] - position).distance <= tolerance.handle) return DrawingHit(anchor: i);
    }
  }
  if (drawing is ChartText) {
    final size = textSize?.call(drawing) ?? const Size(40, 16);
    return (anchors[0] & size).inflate(tolerance.stroke).contains(position) ? const DrawingHit() : null;
  }
  for (final (from, to) in drawingSegments(drawing, p)) {
    if (_distanceToSegment(position, from, to) <= tolerance.stroke) return const DrawingHit();
  }
  return null;
}

Offset _extend(Offset from, Offset through, double reach) {
  final direction = through - from;
  if (direction.distance == 0) return through;
  return through + direction / direction.distance * reach;
}

List<(Offset, Offset)> _rectEdges(Rect r) => [
  (r.topLeft, r.topRight),
  (r.topRight, r.bottomRight),
  (r.bottomRight, r.bottomLeft),
  (r.bottomLeft, r.topLeft),
];

double _distanceToSegment(Offset point, Offset a, Offset b) {
  final ab = b - a;
  final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
  if (lengthSquared == 0) return (point - a).distance;
  final t = (((point - a).dx * ab.dx + (point - a).dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
  return (point - (a + ab * t)).distance;
}

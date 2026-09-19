import 'dart:math';
import 'dart:ui';

import '../models/chart_drawing.dart';
import '../models/coordinates.dart';

/// The Fibonacci retracement ratios, bottom to top.
const List<double> fibLevels = [0, 0.236, 0.382, 0.5, 0.618, 0.786, 1];

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

/// Pixels a pointer may miss a line by and still hit it.
const double drawingHitTolerance = 6;

/// Pixels a pointer may miss an anchor by and still grab its handle.
const double handleHitTolerance = 9;

/// The screen positions of a drawing's anchors.
List<Offset> drawingAnchors(ChartDrawing drawing, DrawingProjection p) => [
  for (final c in drawing.points) p.offsetOf(c),
];

/// The straight strokes of a drawing, extended lines run out past the pane.
List<(Offset, Offset)> drawingSegments(ChartDrawing drawing, DrawingProjection p) {
  final a = drawingAnchors(drawing, p);
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
    ChartParallelChannel() => [(a[0], a[1]), (a[2], a[2] + (a[1] - a[0]))],
    ChartFibRetracement() => [
      for (final level in fibLevels)
        (Offset(min(a[0].dx, a[1].dx), _fibY(a, level)), Offset(max(a[0].dx, a[1].dx), _fibY(a, level))),
    ],
    ChartText() => const [],
  };
}

/// The filled area of a drawing, if it has one.
Path? drawingArea(ChartDrawing drawing, DrawingProjection p) {
  final a = drawingAnchors(drawing, p);
  return switch (drawing) {
    ChartRectangle() || ChartMeasure() => Path()..addRect(Rect.fromPoints(a[0], a[1])),
    ChartParallelChannel() =>
      Path()
        ..moveTo(a[0].dx, a[0].dy)
        ..lineTo(a[1].dx, a[1].dy)
        ..lineTo(a[2].dx + (a[1].dx - a[0].dx), a[2].dy + (a[1].dy - a[0].dy))
        ..lineTo(a[2].dx, a[2].dy)
        ..close(),
    _ => null,
  };
}

/// The y of a Fibonacci level between the two anchors' prices.
double _fibY(List<Offset> a, double level) => a[0].dy + (a[1].dy - a[0].dy) * level;

/// Whether [position] is on the drawing: on an anchor when [handles] are
/// live, else on a stroke or inside a filled area.
DrawingHit? hitTestDrawing(
  ChartDrawing drawing,
  Offset position,
  DrawingProjection p, {
  required bool handles,
  Size Function(ChartText text)? textSize,
}) {
  if (drawing.hidden) return null;
  final anchors = drawingAnchors(drawing, p);
  if (handles) {
    for (var i = 0; i < anchors.length; i++) {
      if ((anchors[i] - position).distance <= handleHitTolerance) return DrawingHit(anchor: i);
    }
  }
  if (drawing is ChartText) {
    final size = textSize?.call(drawing) ?? const Size(40, 16);
    return (anchors[0] & size).inflate(drawingHitTolerance).contains(position) ? const DrawingHit() : null;
  }
  for (final (from, to) in drawingSegments(drawing, p)) {
    if (_distanceToSegment(position, from, to) <= drawingHitTolerance) return const DrawingHit();
  }
  final area = drawingArea(drawing, p);
  if (area != null && area.contains(position)) return const DrawingHit();
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

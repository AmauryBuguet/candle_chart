import 'dart:ui';

import '../models/chart_drawing.dart';

/// Draws a dashed line from [p1] to [p2] with the given dash [pattern] of
/// alternating dash and gap lengths.
void drawDashedLine({
  required Canvas canvas,
  required Offset p1,
  required Offset p2,
  required List<double> pattern,
  required Paint paint,
}) {
  assert(pattern.length.isEven);
  final distance = (p2 - p1).distance;
  if (distance == 0) return;
  final normalizedPattern = pattern.map((width) => width / distance).toList();
  final points = <Offset>[];
  double t = 0;
  int i = 0;
  while (t < 1) {
    points.add(Offset.lerp(p1, p2, t)!);
    t += normalizedPattern[i++]; // dashWidth
    points.add(Offset.lerp(p1, p2, t.clamp(0, 1))!);
    t += normalizedPattern[i++]; // dashSpace
    i %= normalizedPattern.length;
  }
  canvas.drawPoints(PointMode.lines, points, paint);
}

/// A stroke in one of the drawing line styles.
void drawStyledLine({
  required Canvas canvas,
  required Offset p1,
  required Offset p2,
  required ChartLineStyle style,
  required Paint paint,
}) {
  switch (style) {
    case ChartLineStyle.solid:
      canvas.drawLine(p1, p2, paint);
    case ChartLineStyle.dashed:
      drawDashedLine(canvas: canvas, p1: p1, p2: p2, pattern: const [8, 6], paint: paint);
    case ChartLineStyle.dotted:
      drawDashedLine(canvas: canvas, p1: p1, p2: p2, pattern: const [2, 4], paint: paint);
  }
}

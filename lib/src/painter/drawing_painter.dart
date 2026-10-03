import 'package:flutter/painting.dart';

import '../internal/drawing_geometry.dart';
import '../models/chart_drawing.dart';
import '../models/coordinates.dart';
import 'dashes.dart';

/// Draws the user's drawings into the price pane, and the handles of the
/// selected one.
class DrawingPainter {
  DrawingPainter({
    required this.canvas,
    required this.projection,
    required this.textStyle,
    required this.formatPrice,
    required this.intervalMs,
    required this.handleFill,
    this.handleSpot,
  });

  final Canvas canvas;
  final DrawingProjection projection;
  final TextStyle textStyle;
  final String Function(double price) formatPrice;
  final int intervalMs;

  /// The chart's background, which hollows the handles out.
  final Color handleFill;

  /// Where a horizontal or vertical line keeps its handle.
  final Coordinates? handleSpot;

  void draw(ChartDrawing drawing) {
    if (drawing.hidden) return;
    canvas.save();
    canvas.clipRect(projection.rect);

    final area = drawingArea(drawing, projection);
    if (area != null) canvas.drawPath(area, Paint()..color = drawing.color.withAlpha(30));

    final paint = Paint()
      ..color = drawing.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = drawing.selected ? drawing.width + 1 : drawing.width;
    for (final (from, to) in drawingSegments(drawing, projection)) {
      drawStyledLine(canvas: canvas, p1: from, p2: to, style: drawing.lineStyle, paint: paint);
    }
    for (final (from, to, level) in fibLevelLines(drawing, projection)) {
      paint.color = level.color ?? drawing.color;
      drawStyledLine(canvas: canvas, p1: from, p2: to, style: drawing.lineStyle, paint: paint);
    }

    switch (drawing) {
      case ChartFibRetracement():
        _drawFibLabels(drawing, (ratio) => fibPrice(drawing.points, ratio));
      case ChartFibExtension():
        _drawFibLabels(drawing, (ratio) => fibExtensionPrice(drawing.points, ratio));
      case ChartMeasure():
        _drawMeasureLabel(drawing);
      case ChartText():
        _drawText(drawing);
      default:
        break;
    }

    if (drawing.selected) _drawHandles(drawing);
    canvas.restore();
  }

  /// The size a text note takes, for hit-testing it.
  Size textSize(ChartText text) => _textPainter(text.text, text.color).size;

  /// Each shown level's ratio and price over its left end, in its colour.
  void _drawFibLabels(ChartDrawing drawing, double Function(double ratio) priceOf) {
    for (final (from, _, level) in fibLevelLines(drawing, projection)) {
      final tp = _textPainter(
        '${level.ratio.toStringAsFixed(3)}  ${formatPrice(priceOf(level.ratio))}',
        level.color ?? drawing.color,
      );
      tp.paint(canvas, Offset(from.dx + 4, from.dy - tp.height - 1));
    }
  }

  void _drawMeasureLabel(ChartMeasure drawing) {
    final from = drawing.points[0];
    final to = drawing.points[1];
    final change = to.price - from.price;
    final percent = from.price == 0 ? 0.0 : change / from.price * 100;
    final bars = intervalMs == 0 ? 0 : ((to.timestamp - from.timestamp) / intervalMs).round();
    final sign = change >= 0 ? '+' : '';
    final label =
        '$sign${formatPrice(change)} ($sign${percent.toStringAsFixed(2)}%)\n'
        '$bars bars, ${_duration(Duration(milliseconds: (to.timestamp - from.timestamp).abs()))}';
    final tp = _textPainter(label, _contrasting(drawing.color));
    final rect = Rect.fromPoints(projection.offsetOf(from), projection.offsetOf(to));
    final above = change >= 0;
    final origin = Offset(rect.center.dx - tp.width / 2, above ? rect.top - tp.height - 10 : rect.bottom + 6);
    final box = (origin & tp.size).inflate(4);
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(3)), Paint()..color = drawing.color);
    tp.paint(canvas, origin);
  }

  void _drawText(ChartText drawing) {
    final anchor = projection.offsetOf(drawing.points[0]);
    final tp = _textPainter(drawing.text, drawing.color);
    tp.paint(canvas, anchor);
    if (drawing.selected) {
      canvas.drawRect(
        (anchor & tp.size).inflate(3),
        Paint()
          ..color = drawing.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
  }

  void _drawHandles(ChartDrawing drawing) {
    final ring = Paint()..color = drawing.color;
    final fill = Paint()..color = handleFill;
    for (final anchor in drawingAnchors(drawing, projection, handleAt: handleSpot)) {
      canvas.drawCircle(anchor, 4.5, ring);
      canvas.drawCircle(anchor, 2.5, fill);
    }
  }

  TextPainter _textPainter(String text, Color color) => TextPainter(
    text: TextSpan(
      text: text,
      style: textStyle.copyWith(color: color),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();

  static Color _contrasting(Color color) =>
      color.computeLuminance() > 0.5 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

  static String _duration(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }
}

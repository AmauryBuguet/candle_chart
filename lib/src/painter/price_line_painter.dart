import 'dart:ui';

import '../internal/drawing_geometry.dart';
import '../models/axis.dart';
import '../models/chart_line.dart';
import '../models/chart_order_line.dart';
import 'dashes.dart';

/// Draws the host's horizontal price lines and its orders in the price pane.
class PriceLinePainter {
  PriceLinePainter({
    required this.canvas,
    required this.projection,
    required this.priceAxis,
    required this.timeAxis,
  });

  final Canvas canvas;

  /// The price pane's mapping.
  final DrawingProjection projection;
  final PriceAxis priceAxis;
  final TimeAxis timeAxis;

  void drawLines(List<ChartLine> lines) {
    final chartRect = projection.rect;
    canvas.save();
    canvas.clipRect(chartRect);
    for (final line in lines.where((e) => e.price >= priceAxis.start && e.price <= priceAxis.end)) {
      final dotPaint = Paint()
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.round
        ..color = line.color
        ..strokeWidth = 12.0;
      final paint = Paint()
        ..color = line.color
        ..strokeWidth = line.selected ? 2.0 : 1.0;
      final y = projection.yForPrice(line.price);
      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), paint);
      canvas.drawPoints(PointMode.points, [Offset(chartRect.left, y), Offset(chartRect.right, y)], dotPaint);
    }
    canvas.restore();
  }

  void drawOrderLines(List<ChartOrderLine> orderLines) {
    final chartRect = projection.rect;
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12.0;
    for (final order in orderLines.where((e) => e.newPrice >= priceAxis.start && e.newPrice <= priceAxis.end)) {
      if (order.timestamp < timeAxis.end) {
        final isEditing = order.originalPrice != order.newPrice;

        final paint = Paint()
          ..color = order.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = order.selected ? 2.5 : 1.5;
        final x = projection.xForTime(order.timestamp < timeAxis.start ? timeAxis.start : order.timestamp);
        final y = projection.yForPrice(order.newPrice);

        drawDashedLine(
          canvas: canvas,
          p1: Offset(isEditing ? chartRect.left : x, y),
          p2: Offset(chartRect.right, y),
          pattern: [6.0, 6.0],
          paint: paint,
        );

        canvas.drawPoints(PointMode.points, [Offset(x, y)], dotPaint..color = order.color);

        if (isEditing && order.originalPrice >= priceAxis.start && order.originalPrice <= priceAxis.end) {
          final oldY = projection.yForPrice(order.originalPrice);
          drawDashedLine(
            canvas: canvas,
            p1: Offset(x, oldY),
            p2: Offset(chartRect.right, oldY),
            pattern: [6.0, 6.0],
            paint: paint..color = order.color.withAlpha(100),
          );
        }
      }
    }
  }
}

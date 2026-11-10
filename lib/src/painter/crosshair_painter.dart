import 'package:flutter/widgets.dart';

import '../internal/candle_time.dart';
import '../internal/chart_layout.dart';
import '../internal/drawing_geometry.dart';
import '../internal/price_scale.dart' as scale;
import '../models/axis.dart';
import '../models/chart_candle.dart';
import '../models/chart_indicator.dart';
import '../models/chart_style.dart';
import 'axis_painter.dart';
import 'dashes.dart';

/// Draws the crosshair through every pane, snapped to the nearest candle in
/// time, with its time label under the panes and the value under the
/// pointer in the right gutter.
class CrosshairPainter {
  CrosshairPainter({
    required this.canvas,
    required this.projection,
    required this.layout,
    required this.style,
    required this.candles,
    required this.priceAxis,
    required this.timeAxis,
    required this.logScale,
    required this.armed,
    required this.formatPrice,
    required this.panes,
    required this.paneAxes,
  });

  final Canvas canvas;

  /// The price pane's mapping.
  final DrawingProjection projection;
  final ChartLayout layout;
  final ChartStyle style;
  final List<ChartCandle> candles;
  final PriceAxis priceAxis;
  final TimeAxis timeAxis;
  final bool logScale;

  /// Whether a tool is in hand, the crosshair then in its own colour.
  final bool armed;
  final String Function(double price) formatPrice;
  final List<ChartPaneIndicator> panes;
  final List<PriceAxis> paneAxes;

  /// Draws the crosshair and its axis-aligned labels.
  void draw(Offset position, String dateFormat) {
    final chartRect = projection.rect;
    final backgroundPaint = Paint()..color = style.colors.crosshairLabelBackground;
    final paint = Paint()
      ..color = armed ? style.colors.cursor : style.colors.crosshair
      ..style = PaintingStyle.stroke
      ..strokeWidth = armed ? 0.8 : 0.6;

    double dx = position.dx;
    if (candles.isNotEmpty) {
      final time = projection.timeForX(dx);
      dx = projection.xForTime(nearestCandleTime(time, candles));
    }

    drawDashedLine(
      canvas: canvas,
      p1: Offset(chartRect.left, position.dy),
      p2: Offset(chartRect.right, position.dy),
      pattern: [10.0, 10.0],
      paint: paint,
    );
    drawDashedLine(
      canvas: canvas,
      p1: Offset(dx, layout.plotTop),
      p2: Offset(dx, layout.plotBottom),
      pattern: [10.0, 10.0],
      paint: paint,
    );

    // Draw time label
    final ms = projection.timeForX(dx);
    final timeMs = DateTime.fromMillisecondsSinceEpoch(ms);
    final timeText = formatTimeLabel(timeMs, dateFormat, style);
    final timePainter = TextPainter(
      text: TextSpan(
        text: timeText,
        style: style.labelStyle.textStyle.copyWith(color: style.colors.crosshairLabelText),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final timeRect = Rect.fromLTWH(
      dx - timePainter.width / 2 - style.labelStyle.padding,
      layout.plotBottom + style.labelStyle.labelMargin - style.labelStyle.padding,
      timePainter.width + style.labelStyle.padding * 2,
      timePainter.height + style.labelStyle.padding * 2,
    );
    canvas.drawRect(timeRect, backgroundPaint);
    timePainter.paint(canvas, Offset(dx - timePainter.width / 2, layout.plotBottom + style.labelStyle.labelMargin));

    // The value under the pointer, in whichever pane it is in.
    final paneIndex = layout.paneAt(position);
    final String priceText;
    if (paneIndex == null) {
      priceText = formatPrice(projection.priceForY(position.dy));
    } else {
      final axis = paneAxes[paneIndex];
      // A pane's axis is linear, unless it is the very price axis object.
      final value = scale.priceForY(
        position.dy,
        axis,
        layout.paneRects[paneIndex],
        logScale: logScale && identical(axis, priceAxis),
      );
      priceText = panes[paneIndex].formatValue(value);
    }
    final pricePainter = TextPainter(
      text: TextSpan(
        text: priceText,
        style: style.labelStyle.textStyle.copyWith(color: style.colors.crosshairLabelText),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final priceRect = Rect.fromLTWH(
      chartRect.right + style.labelStyle.labelMargin - style.labelStyle.padding,
      position.dy - pricePainter.height / 2 - style.labelStyle.padding,
      pricePainter.width + style.labelStyle.padding * 2,
      pricePainter.height + style.labelStyle.padding * 2,
    );
    canvas.drawRect(priceRect, backgroundPaint);
    pricePainter.paint(
      canvas,
      Offset(chartRect.right + style.labelStyle.labelMargin, position.dy - pricePainter.height / 2),
    );
  }
}

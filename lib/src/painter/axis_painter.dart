import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../internal/chart_layout.dart';
import '../internal/price_scale.dart' as scale;
import '../models/axis.dart';
import '../models/chart_style.dart';
import 'axis_ticks.dart';

/// Draws the grid and the axis labels: each pane's value ticks in the right
/// gutter, the time ticks under the last pane.
class AxisPainter {
  AxisPainter({required this.canvas, required this.style, required this.layout, required this.timeAxis});

  final Canvas canvas;
  final ChartStyle style;
  final ChartLayout layout;
  final TimeAxis timeAxis;

  /// A hairline: the colour's alpha is what keeps the grid quiet, and a
  /// thinner stroke would anti-alias it out of sight.
  Paint get _gridPaint => Paint()
    ..color = style.colors.grid
    ..strokeWidth = 1.0;

  /// One pane's value ticks: a grid line across it and a label in the right
  /// gutter, clipped to the pane so a tick at its edge does not stray into
  /// the next.
  void drawValueAxis(Rect rect, PriceAxis axis, String Function(double) format, {bool logScale = false}) {
    final minSpacing = style.labelStyle.minSpacingPxPriceAxis;
    final ticks = logScale
        ? logPriceTicks(axis.start, axis.end, rect.height, minSpacing)
        : nicePriceTicks(axis.start, axis.end, rect.height, minSpacing);
    final gridPaint = _gridPaint;
    for (final tick in ticks) {
      final y = scale.yForPrice(tick, axis, rect, logScale: logScale);
      if (style.grid) canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: format(tick), style: style.labelStyle.textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      if (y - tp.height / 2 < rect.top - 1 || y + tp.height / 2 > rect.bottom + 1) continue;
      tp.paint(canvas, Offset(rect.right + style.labelStyle.labelMargin, y - tp.height / 2));
    }
  }

  /// The time ticks: a grid line down through every pane and a label under
  /// the last one. Returns the label format for the crosshair to reuse.
  String drawTimeAxis(double Function(int time) xForTime) {
    final chartRect = layout.priceRect;
    final timeTicks = niceTimeTicks(timeAxis, chartRect.width, style.labelStyle.minSpacingPxTimeAxis);
    final gridPaint = _gridPaint;
    for (final tick in timeTicks.$1) {
      final x = xForTime(tick.millisecondsSinceEpoch);
      if (style.grid) canvas.drawLine(Offset(x, layout.plotTop), Offset(x, layout.plotBottom), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: formatTimeLabel(tick, timeTicks.$2, style), style: style.labelStyle.textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, layout.plotBottom + style.labelStyle.labelMargin));
    }
    return timeTicks.$2;
  }
}

/// Formats a time label using intl.
String formatTimeLabel(DateTime dt, String dateFormat, ChartStyle style) {
  if (dt.month == 1 && dt.day == 1) {
    return DateFormat('yyyy', style.labelStyle.locale).format(dt);
  } else if (dt.day == 1 && dt.hour == 0) {
    return DateFormat('MMM', style.labelStyle.locale).format(dt);
  } else if (dt.hour == 0 && dt.minute == 0) {
    return DateFormat('dd/MM', style.labelStyle.locale).format(dt);
  } else {
    return DateFormat(dateFormat, style.labelStyle.locale).format(dt);
  }
}

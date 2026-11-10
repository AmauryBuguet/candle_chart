import 'dart:math';

import 'package:flutter/widgets.dart';

import '../internal/candle_time.dart';
import '../internal/chart_layout.dart';
import '../internal/drawing_geometry.dart';
import '../internal/indicator_render.dart';
import '../internal/price_scale.dart' as scale;
import '../models/axis.dart';
import '../models/chart_candle.dart';
import '../models/chart_drawing.dart';
import '../models/chart_indicator.dart';
import '../models/chart_line.dart';
import '../models/chart_order_line.dart';
import '../models/chart_position.dart';
import '../models/chart_style.dart';
import '../models/coordinates.dart';
import 'axis_painter.dart';
import 'candle_painter.dart';
import 'crosshair_painter.dart';
import 'dashes.dart';
import 'drawing_painter.dart';
import 'last_price_painter.dart';
import 'position_painter.dart';
import 'price_line_painter.dart';
import 'profile_painter.dart';
import 'series_painter.dart';

/// An indicator with its computed series.
typedef IndicatorEntry<T extends ChartIndicator> = (T indicator, IndicatorRender render);

/// Paints the trading chart: the price pane with its candles, overlays,
/// lines, orders and positions, then one pane per pane indicator, the grid,
/// the forming candle's price label and the crosshair running through them
/// all.
class ChartPainter extends CustomPainter {
  /// Creates a [ChartPainter].
  ///
  /// All parameters are required except crosshairPosition.
  const ChartPainter({
    required this.candles,
    required this.lines,
    required this.orderLines,
    this.style = const ChartStyle(),
    required this.layout,
    required this.priceAxis,
    required this.timeAxis,
    this.crosshairPosition,
    this.crosshairArmed = false,
    this.candleCountdown,
    required this.positions,
    required this.formatPrice,
    this.overlays = const [],
    this.panes = const [],
    this.paneAxes = const [],
    this.logScale = false,
    this.drawings = const [],
    this.handleSpot,
    this.placing,
  });

  final List<ChartCandle> candles;
  final List<ChartLine> lines;
  final List<ChartOrderLine> orderLines;
  final ChartStyle style;
  final ChartLayout layout;
  final PriceAxis priceAxis;
  final TimeAxis timeAxis;
  final Offset? crosshairPosition;

  /// Whether a tool is in hand: the crosshair is then where its next point
  /// lands — the pointer on desktop, the cursor on a phone — and is drawn
  /// in its own colour and thicker.
  final bool crosshairArmed;

  /// The time left before the forming candle closes, under its price in
  /// the right gutter; none when null.
  final String? candleCountdown;
  final List<ChartPosition> positions;

  /// Formats a price for display in axis/crosshair labels.
  final String Function(double price) formatPrice;

  final List<IndicatorEntry<ChartOverlay>> overlays;
  final List<IndicatorEntry<ChartPaneIndicator>> panes;

  /// One value axis per entry of [panes].
  final List<PriceAxis> paneAxes;

  /// Whether the price pane's axis is logarithmic.
  final bool logScale;

  /// The user's drawings, in the price pane.
  final List<ChartDrawing> drawings;

  /// Where a selected horizontal or vertical line keeps its handle.
  final Coordinates? handleSpot;

  /// The drawing being placed, its last point following the pointer.
  final ChartDrawing? placing;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = style.colors;
    final chartRect = layout.priceRect;
    final projection = projectionFor(chartRect);

    // Calculate visible candle indices
    int firstIndex = -1;
    int effectiveEndIndex = -1;

    if (candles.isNotEmpty) {
      firstIndex = candles.indexWhere((e) => e.timestamp >= timeAxis.start);
      if (firstIndex != -1) {
        if (firstIndex > 0) firstIndex--;
        int lastIndex = candles.indexWhere((e) => e.timestamp >= timeAxis.end, firstIndex);
        effectiveEndIndex = (lastIndex != -1 && lastIndex < candles.length - 1)
            ? lastIndex + 1
            : (lastIndex == -1 ? candles.length : lastIndex);
      }
    }

    // Draw background color
    final backgroundPaint = Paint()
      ..color = colors.background
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final axes = AxisPainter(canvas: canvas, style: style, layout: layout, timeAxis: timeAxis);
    axes.drawValueAxis(chartRect, priceAxis, formatPrice, logScale: logScale);
    final dateFormat = axes.drawTimeAxis(projection.xForTime);

    _dimmed(canvas, () {
      final profiles = ProfilePainter(canvas: canvas, projection: projection, priceAxis: priceAxis);
      for (final (overlay, _) in overlays) {
        if (overlay is ChartVolumeProfile) {
          profiles.drawVolumeProfile(candles, firstIndex, effectiveEndIndex, overlay);
        } else if (overlay is ChartOrderBookProfile) {
          profiles.drawOrderBookProfile(overlay);
        }
      }
    });

    final candlePainter = CandlePainter(
      canvas: canvas,
      projection: projection,
      candles: candles,
      firstIndex: firstIndex,
      endIndex: effectiveEndIndex,
      style: style,
      priceAxis: priceAxis,
      timeAxis: timeAxis,
    );
    if (style.chartType == ChartType.line) {
      candlePainter.drawCloseLine();
    } else {
      candlePainter.drawCandles();
    }

    // Studies sit over the candles but under the trade objects.
    final intervalMs = candles.isEmpty ? 1 : candles.first.endTimestamp - candles.first.timestamp;
    _dimmed(
      canvas,
      () => SeriesPainter(
        canvas: canvas,
        rect: chartRect,
        candles: candles,
        firstIndex: firstIndex,
        endIndex: effectiveEndIndex,
        intervalMs: intervalMs,
        xForTime: (t) => _getXPositionFromTime(t, chartRect),
        yForValue: (v) => _getYPositionFromPrice(v, chartRect),
        textStyle: style.labelStyle.textStyle,
      ).draw(_combinedOverlays()),
    );

    // Draft entry/SL/TP lines, then the orders.
    PriceLinePainter(canvas: canvas, projection: projection, priceAxis: priceAxis, timeAxis: timeAxis)
      ..drawLines(lines)
      ..drawOrderLines(orderLines);

    PositionPainter(
      canvas: canvas,
      projection: projection,
      candles: candles,
      timeAxis: timeAxis,
      style: style,
    ).draw(positions);

    if (drawings.isNotEmpty || placing != null) {
      final painter = DrawingPainter(
        canvas: canvas,
        projection: projection,
        textStyle: style.labelStyle.textStyle,
        formatPrice: formatPrice,
        intervalMs: intervalMs,
        handleFill: style.colors.background,
        handleSpot: handleSpot,
      );
      _dimmed(canvas, () {
        for (final drawing in drawings) {
          painter.draw(drawing);
        }
      });
      if (placing != null) painter.draw(placing!);
    }

    for (var i = 0; i < panes.length; i++) {
      final (pane, render) = panes[i];
      final rect = layout.paneRects[i];
      final axis = paneAxes[i];
      _drawHandle(canvas, layout.handleRects[i]);
      axes.drawValueAxis(rect, axis, pane.formatValue);
      _drawLevels(canvas, rect, axis, render.levels);
      SeriesPainter(
        canvas: canvas,
        rect: rect,
        candles: candles,
        firstIndex: firstIndex,
        endIndex: effectiveEndIndex,
        intervalMs: intervalMs,
        xForTime: (t) => _getXPositionFromTime(t, chartRect),
        yForValue: (v) => rect.top + (1 - (v - axis.start) / axis.range) * rect.height,
        textStyle: style.labelStyle.textStyle,
      ).draw(render);
      _drawPaneLabel(canvas, rect, pane.label);
    }

    if (candles.isNotEmpty) {
      LastPricePainter(
        canvas: canvas,
        projection: projection,
        style: style,
        priceAxis: priceAxis,
        formatPrice: formatPrice,
        right: size.width,
      ).draw(candles.last, candleCountdown);
    }

    final position = crosshairPosition;
    if (position != null && (style.crosshair || crosshairArmed) && layout.plotRect.contains(position)) {
      CrosshairPainter(
        canvas: canvas,
        projection: projection,
        layout: layout,
        style: style,
        candles: candles,
        priceAxis: priceAxis,
        timeAxis: timeAxis,
        logScale: logScale,
        armed: crosshairArmed,
        formatPrice: formatPrice,
        panes: [for (final (pane, _) in panes) pane],
        paneAxes: paneAxes,
      ).draw(position, dateFormat);
    }
  }

  /// Paints [paint] at [ChartStyle.studyOpacity], as one layer so crossing
  /// strokes do not darken where they overlap.
  void _dimmed(Canvas canvas, VoidCallback paint) {
    final opacity = style.studyOpacity;
    if (opacity >= 1) return paint();
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    paint();
    canvas.restore();
  }

  /// The price pane's mapping, for drawing geometry.
  DrawingProjection projectionFor(Rect chartRect) => DrawingProjection(
    rect: chartRect,
    xForTime: (t) => _getXPositionFromTime(t, chartRect),
    yForPrice: (p) => _getYPositionFromPrice(p, chartRect),
    timeForX: (x) => _getTimeFromXPosition(x: x, chartRect: chartRect, axis: timeAxis),
    priceForY: (y) => _getPriceFromYPosition(y: y, chartRect: chartRect, axis: priceAxis),
    candleTime: (t) => candleTimeOf(t, candles),
  );

  /// Every overlay's series as one render, so fills go under every line
  /// rather than over the lines of the overlays before them. A band indexes
  /// its own indicator's series, so it is re-based into the combined list.
  IndicatorRender _combinedOverlays() {
    final series = <IndicatorSeries>[];
    final bands = <IndicatorBand>[];
    final boxes = <IndicatorBox>[];
    for (final (_, render) in overlays) {
      final base = series.length;
      series.addAll(render.series);
      boxes.addAll(render.boxes);
      bands.addAll([
        for (final band in render.bands)
          IndicatorBand(first: base + band.first, second: base + band.second, above: band.above, below: band.below),
      ]);
    }
    return IndicatorRender(series: series, bands: bands, boxes: boxes);
  }

  /// The hairline between two panes.
  void _drawHandle(Canvas canvas, Rect handle) {
    final y = handle.center.dy;
    canvas.drawLine(
      Offset(handle.left, y),
      Offset(handle.right, y),
      Paint()
        ..color = style.colors.grid
        ..strokeWidth = 1,
    );
  }

  static const _paneLabelInset = Offset(6, 4);

  /// A pane's name in its top-left corner, left out of a pane too small for it.
  void _drawPaneLabel(Canvas canvas, Rect rect, String label) {
    if (label.isEmpty) return;
    final text = TextPainter(
      text: TextSpan(text: label, style: style.labelStyle.textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: max(0, rect.width - _paneLabelInset.dx * 2));
    if (text.height + _paneLabelInset.dy > rect.height) return;
    text.paint(canvas, rect.topLeft + _paneLabelInset);
  }

  /// A pane's guide lines: an oscillator's bounds, a histogram's zero.
  void _drawLevels(Canvas canvas, Rect rect, PriceAxis axis, List<double> levels) {
    final paint = Paint()
      ..color = style.colors.crosshair.withAlpha(90)
      ..strokeWidth = 0.6;
    for (final level in levels) {
      if (level < axis.start || level > axis.end) continue;
      final y = rect.top + (1 - (level - axis.start) / axis.range) * rect.height;
      drawDashedLine(
        canvas: canvas,
        p1: Offset(rect.left, y),
        p2: Offset(rect.right, y),
        pattern: [4, 4],
        paint: paint,
      );
    }
  }

  /// Converts a price to Y coordinate.
  double _getYPositionFromPrice(double price, Rect chartRect) {
    return scale.yForPrice(price, priceAxis, chartRect, logScale: logScale);
  }

  /// Converts a timestamp to X coordinate.
  double _getXPositionFromTime(int time, Rect chartRect) {
    return chartRect.left + ((time - timeAxis.start) / timeAxis.range) * chartRect.width;
  }

  int _getTimeFromXPosition({required double x, required Rect chartRect, required TimeAxis axis}) {
    final xRatio = (x - chartRect.left) / chartRect.width;
    return axis.start + (axis.range * xRatio).ceil();
  }

  double _getPriceFromYPosition({required double y, required Rect chartRect, required PriceAxis axis}) {
    return scale.priceForY(y, axis, chartRect, logScale: logScale && identical(axis, priceAxis));
  }

  @override
  bool shouldRepaint(covariant ChartPainter oldDelegate) {
    return oldDelegate.crosshairPosition != crosshairPosition ||
        oldDelegate.crosshairArmed != crosshairArmed ||
        oldDelegate.candleCountdown != candleCountdown ||
        oldDelegate.candles != candles ||
        oldDelegate.lines != lines ||
        oldDelegate.orderLines != orderLines ||
        oldDelegate.positions != positions ||
        oldDelegate.style != style ||
        oldDelegate.priceAxis != priceAxis ||
        oldDelegate.timeAxis != timeAxis ||
        oldDelegate.overlays != overlays ||
        oldDelegate.panes != panes ||
        oldDelegate.paneAxes != paneAxes ||
        oldDelegate.layout != layout ||
        oldDelegate.logScale != logScale ||
        oldDelegate.drawings != drawings ||
        oldDelegate.handleSpot != handleSpot ||
        oldDelegate.placing != placing;
  }
}

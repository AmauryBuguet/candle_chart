import 'dart:math';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/chart_margins.dart';
import '../internal/indicators.dart';
import '../internal/timesteps.dart';
import '../models/axis.dart';
import '../models/chart_candle.dart';
import '../models/chart_line.dart';
import '../models/chart_order_line.dart';
import '../models/chart_position.dart';
import '../models/chart_style.dart';
import 'position_samples.dart';

/// Ceiling on the decimal places kept when cleaning up generated tick values,
/// to avoid floating-point noise (e.g. 0.1 + 0.2) — unrelated to any price
/// formatting/precision rule, which is entirely up to [ChartPainter.formatPrice].
const int _maxTickCleanupDecimals = 8;

/// How much of the chart's height the tallest visible volume bar takes.
const double _volumeHeightFraction = 0.2;

/// Paints the trading chart with candlesticks, grid lines, an optional
/// crosshair, VPVR, volume bars and moving averages.
class ChartPainter extends CustomPainter {
  /// Creates a [ChartPainter].
  ///
  /// All parameters are required except crosshairPosition.
  const ChartPainter({
    required this.candles,
    required this.lines,
    required this.orderLines,
    this.style = const ChartStyle(),
    required this.margins,
    required this.priceAxis,
    required this.timeAxis,
    this.crosshairPosition,
    required this.positions,
    required this.formatPrice,
  });

  final List<ChartCandle> candles;
  final List<ChartLine> lines;
  final List<ChartOrderLine> orderLines;
  final ChartStyle style;
  final ChartMargins margins;
  final PriceAxis priceAxis;
  final TimeAxis timeAxis;
  final Offset? crosshairPosition;
  final List<ChartPosition> positions;

  /// Formats a price for display in axis/crosshair labels.
  final String Function(double price) formatPrice;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = style.colors;
    final Rect chartRect = Rect.fromLTWH(
      margins.left,
      margins.top,
      size.width - margins.left - margins.right,
      size.height - margins.top - margins.bottom,
    );

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

    // Draw axis graduations
    final dateFormat = _drawAxisLabels(canvas, chartRect);

    // Draw VPVR (Visible Range Volume Profile)
    if (style.vpvr) {
      _drawVPVR(canvas, chartRect, firstIndex, effectiveEndIndex);
    }

    if (style.volume) {
      _drawVolume(canvas, chartRect, firstIndex, effectiveEndIndex);
    }

    // Draw crosshair if active and inside chart area
    if (crosshairPosition != null && style.crosshair && chartRect.contains(crosshairPosition!)) {
      _drawCrosshair(canvas, crosshairPosition!, candles.firstOrNull, dateFormat, chartRect);
    }

    // Draw candles
    _drawCandles(canvas, chartRect, firstIndex, effectiveEndIndex);

    // Studies sit over the candles but under the trade objects.
    _drawBollinger(canvas, chartRect, firstIndex, effectiveEndIndex);
    _drawEmas(canvas, chartRect, firstIndex, effectiveEndIndex);

    // Draw lines (e.g. draft entry/SL/TP lines)
    _drawLines(canvas, chartRect);

    // Draw order overlays
    _drawOrderLines(canvas, chartRect);

    // Draw current position
    _drawPositions(canvas, chartRect);
  }

  /// Draws the Visible Range Volume Profile on the right side of the chart.
  void _drawVPVR(Canvas canvas, Rect chartRect, int firstIndex, int effectiveEndIndex) {
    if (firstIndex == -1 || effectiveEndIndex == -1 || priceAxis.range <= 0) return;

    // 1. Setup Price Bins (e.g., 100 vertical rows)
    const int binsCount = 100;
    final double binPriceHeight = priceAxis.range / binsCount;
    if (binPriceHeight <= 0) return;

    final List<double> volumeBins = List.filled(binsCount, 0.0);
    double maxVol = 0.0;
    int pocIndex = -1;

    // 2. Distribute volume of visible candles across bins
    for (int i = firstIndex; i < effectiveEndIndex; i++) {
      final candle = candles[i];
      int startBin = ((candle.low - priceAxis.start) / binPriceHeight).floor();
      int endBin = ((candle.high - priceAxis.start) / binPriceHeight).floor();

      startBin = startBin.clamp(0, binsCount - 1);
      endBin = endBin.clamp(0, binsCount - 1);

      int binsSpanned = endBin - startBin + 1;
      double volPerBin = candle.volume / binsSpanned;

      for (int j = startBin; j <= endBin; j++) {
        volumeBins[j] += volPerBin;
      }
    }

    // 3. Find Max Volume for relative sizing
    for (int i = 0; i < binsCount; i++) {
      if (volumeBins[i] > maxVol) {
        maxVol = volumeBins[i];
        pocIndex = i;
      }
    }

    if (maxVol == 0) return;

    // 4. Draw the Histogram
    canvas.save();
    canvas.clipRect(chartRect);

    final double maxBarWidth = chartRect.width * 0.30;

    final Paint vpvrPaint = Paint()
      ..color = style.colors.grid.withAlpha(60)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < binsCount; i++) {
      if (volumeBins[i] == 0) continue;

      final double barWidth = (volumeBins[i] / maxVol) * maxBarWidth;
      final double priceBottom = priceAxis.start + i * binPriceHeight;
      final double priceTop = priceBottom + binPriceHeight;

      final double yBottom = _getYPositionFromPrice(priceBottom, chartRect);
      final double yTop = _getYPositionFromPrice(priceTop, chartRect);

      final Rect barRect = Rect.fromLTRB(chartRect.right - barWidth, yTop, chartRect.right, yBottom);

      canvas.drawRect(barRect, vpvrPaint);
    }

    // 5. Draw Point of Control (POC) Line
    if (pocIndex != -1) {
      // Calculate the exact price bounds for the POC bin
      final double priceBottom = priceAxis.start + pocIndex * binPriceHeight;
      final double priceTop = priceBottom + binPriceHeight;

      // Convert prices to Y coordinates on the canvas
      final double yBottom = _getYPositionFromPrice(priceBottom, chartRect);
      final double yTop = _getYPositionFromPrice(priceTop, chartRect);

      // Create a rectangle that spans the max bar width and matches the bin's exact height
      final Rect pocRect = Rect.fromLTRB(
        chartRect.right - maxBarWidth,
        yTop,
        chartRect.right,
        yBottom,
      );

      final Paint pocPaint = Paint()
        ..color = style.colors.doji
        ..style = PaintingStyle.fill;
      canvas.drawRect(pocRect, pocPaint);
    }

    canvas.restore();
  }

  void _drawOrderLines(Canvas canvas, Rect chartRect) {
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
        final x = _getXPositionFromTime(
          order.timestamp < timeAxis.start ? timeAxis.start : order.timestamp,
          chartRect,
        );
        final y = _getYPositionFromPrice(order.newPrice, chartRect);

        _drawDashedLine(
          canvas: canvas,
          p1: Offset(isEditing ? chartRect.left : x, y),
          p2: Offset(chartRect.right, y),
          pattern: [6.0, 6.0],
          paint: paint,
        );

        canvas.drawPoints(PointMode.points, [Offset(x, y)], dotPaint..color = order.color);

        if (isEditing && order.originalPrice >= priceAxis.start && order.originalPrice <= priceAxis.end) {
          final oldY = _getYPositionFromPrice(order.originalPrice, chartRect);
          _drawDashedLine(
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

  void _drawPositions(Canvas canvas, Rect chartRect) {
    canvas.save();
    canvas.clipRect(chartRect);

    final double timeScale = chartRect.width / timeAxis.range;

    double getX(int t) => chartRect.left + (t - timeAxis.start) * timeScale;
    double getY(double p) => chartRect.top + (1 - (p - priceAxis.start) / priceAxis.range) * chartRect.height;

    for (final position in positions) {
      final bool isOpen = position.exit == null;
      if (isOpen && candles.isEmpty) continue;

      // A forming candle's close is the live price, and it is drawn at the
      // right edge of that candle's slot rather than at its centre.
      final int exitTimestamp = isOpen ? closeTime(candles.last) : position.exit!.timestamp;
      final double exitPrice = isOpen ? candles.last.close : position.exit!.price;

      if (exitTimestamp < timeAxis.start || position.entry.timestamp > timeAxis.end) {
        continue;
      }

      final double entryX = getX(position.entry.timestamp);
      final double entryY = getY(position.entry.price);
      final double exitX = getX(exitTimestamp);
      final double exitY = getY(exitPrice);

      final bool isLong = position.side == ChartPositionSide.long;
      final Path winPath = Path();
      final Path lossPath = Path();

      int getState(double p) {
        if ((p - position.entry.price).abs() < 0.000001) return 0;
        if (isLong) return p > position.entry.price ? 1 : -1;
        return p < position.entry.price ? 1 : -1;
      }

      void startPath(int state, double x, double y) {
        if (state == 1) {
          winPath.moveTo(x, y);
        } else if (state == -1) {
          lossPath.moveTo(x, y);
        }
      }

      void addToPath(int state, double x, double y) {
        if (state == 1) {
          winPath.lineTo(x, y);
        } else if (state == -1) {
          lossPath.lineTo(x, y);
        }
      }

      void closeActivePath(int state) {
        if (state == 1) {
          winPath.close();
        } else if (state == -1) {
          lossPath.close();
        }
      }

      double prevX = entryX;
      double prevY = entryY;
      double prevPrice = position.entry.price;
      int currentPathState = 0;

      final List<(int, double)> samples = positionSamples(
        candles: candles,
        entryTimestamp: position.entry.timestamp,
        exitTimestamp: exitTimestamp,
        exitPrice: exitPrice,
      );

      int i = 0;
      while (true) {
        final (int nextTs, double nextPrice) = samples[i];
        final bool isLast = i == samples.length - 1;

        final double nextX = getX(nextTs);
        final double nextY = getY(nextPrice);

        int prevState = getState(prevPrice);
        int nextState = getState(nextPrice);

        if (prevState != 0 && nextState != 0 && prevState != nextState) {
          double ratio = (position.entry.price - prevPrice) / (nextPrice - prevPrice);
          double interX = prevX + (nextX - prevX) * ratio;

          addToPath(currentPathState, interX, entryY);
          closeActivePath(currentPathState);

          currentPathState = nextState;
          startPath(currentPathState, interX, entryY);
          addToPath(currentPathState, nextX, nextY);
        } else if (prevState == 0 && nextState != 0) {
          if (currentPathState == 0) {
            currentPathState = nextState;
            startPath(currentPathState, prevX, prevY);
            addToPath(currentPathState, nextX, nextY);
          } else if (currentPathState != nextState) {
            closeActivePath(currentPathState);
            currentPathState = nextState;
            startPath(currentPathState, prevX, prevY);
            addToPath(currentPathState, nextX, nextY);
          } else {
            addToPath(currentPathState, nextX, nextY);
          }
        } else {
          if (currentPathState != 0) {
            addToPath(currentPathState, nextX, nextY);
          }
        }

        prevX = nextX;
        prevY = nextY;
        prevPrice = nextPrice;

        if (isLast) break;
        i++;
      }

      if (currentPathState != 0) {
        if (currentPathState == 1) {
          winPath.lineTo(prevX, entryY);
        } else {
          lossPath.lineTo(prevX, entryY);
        }

        closeActivePath(currentPathState);
      }

      canvas.drawPath(
        winPath,
        Paint()
          ..color = style.colors.positionProfit.withAlpha(100)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        lossPath,
        Paint()
          ..color = style.colors.positionLoss.withAlpha(100)
          ..style = PaintingStyle.fill,
      );

      final dotPaint = Paint()
        ..color = isLong ? style.colors.positionProfit : style.colors.positionLoss
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 12.0;

      canvas.drawPoints(PointMode.points, [Offset(entryX, entryY)], dotPaint);

      if (!isOpen) {
        dotPaint.color = isLong ? style.colors.positionLoss : style.colors.positionProfit;
        canvas.drawPoints(PointMode.points, [Offset(exitX, exitY)], dotPaint);
      }
    }

    canvas.restore();
  }

  void _drawLines(Canvas canvas, Rect chartRect) {
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
      final y = _getYPositionFromPrice(line.price, chartRect);
      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), paint);
      canvas.drawPoints(PointMode.points, [Offset(chartRect.left, y), Offset(chartRect.right, y)], dotPaint);
    }
    canvas.restore();
  }

  /// Renders all visible candles.
  void _drawCandles(Canvas canvas, Rect chartRect, int firstIndex, int effectiveEndIndex) {
    if (firstIndex == -1 || effectiveEndIndex == -1) return;

    // Use the first visible candle to determine the time difference
    final diffTs = candles[firstIndex].endTimestamp - candles[firstIndex].timestamp;
    final double candleDemiWidth = chartRect.width * 0.35 * diffTs / timeAxis.range;

    canvas.save();
    canvas.clipRect(chartRect);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final bodyPaint = Paint()..style = PaintingStyle.fill;

    for (int i = firstIndex; i < effectiveEndIndex; i++) {
      final candle = candles[i];

      if (candle.low > priceAxis.end || candle.high < priceAxis.start) {
        continue;
      }

      paint.color = _colorFromCandle(candle);
      bodyPaint.color = paint.color;

      final x = _getXPositionFromTime(candle.timestamp, chartRect);
      final openY = _getYPositionFromPrice(candle.open, chartRect);
      final closeY = _getYPositionFromPrice(candle.close, chartRect);
      final highY = _getYPositionFromPrice(candle.high, chartRect);
      final lowY = _getYPositionFromPrice(candle.low, chartRect);

      final top = min(openY, closeY);
      final bottom = max(openY, closeY);

      canvas.drawLine(Offset(x, highY), Offset(x, top), paint);
      canvas.drawLine(Offset(x, bottom), Offset(x, lowY), paint);

      final bodyRect = Rect.fromLTWH(x - candleDemiWidth, top, candleDemiWidth * 2, max(1.0, bottom - top));
      canvas.drawRect(bodyRect, _fillsBody(candle) ? bodyPaint : paint);
    }

    canvas.restore();
  }

  /// Volume bars along the bottom edge, as wide as the candle bodies and
  /// scaled so the busiest visible candle reaches [_volumeHeightFraction].
  void _drawVolume(Canvas canvas, Rect chartRect, int firstIndex, int effectiveEndIndex) {
    if (firstIndex == -1 || effectiveEndIndex == -1) return;

    double maxVolume = 0;
    for (int i = firstIndex; i < effectiveEndIndex; i++) {
      maxVolume = max(maxVolume, candles[i].volume);
    }
    if (maxVolume <= 0) return;

    final diffTs = candles[firstIndex].endTimestamp - candles[firstIndex].timestamp;
    final double candleDemiWidth = chartRect.width * 0.35 * diffTs / timeAxis.range;
    final double maxHeight = chartRect.height * _volumeHeightFraction;

    canvas.save();
    canvas.clipRect(chartRect);

    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = firstIndex; i < effectiveEndIndex; i++) {
      final candle = candles[i];
      if (candle.volume <= 0) continue;

      paint.color = _colorFromCandle(candle).withAlpha(70);
      final x = _getXPositionFromTime(candle.timestamp, chartRect);
      final height = max(1.0, candle.volume / maxVolume * maxHeight);
      canvas.drawRect(
        Rect.fromLTWH(x - candleDemiWidth, chartRect.bottom - height, candleDemiWidth * 2, height),
        paint,
      );
    }

    canvas.restore();
  }

  /// One polyline per average, over the visible candles plus one on each
  /// side so the line runs to the edges rather than stopping at the last
  /// candle centre.
  void _drawEmas(Canvas canvas, Rect chartRect, int firstIndex, int effectiveEndIndex) {
    if (style.emas.isEmpty || firstIndex == -1 || effectiveEndIndex == -1) return;

    canvas.save();
    canvas.clipRect(chartRect);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;
    final from = max(0, firstIndex - 1);
    final to = min(candles.length, effectiveEndIndex + 1);

    for (final ema in style.emas) {
      final values = exponentialMovingAverage(candles, ema.period);
      final path = Path();
      bool started = false;
      for (int i = from; i < to; i++) {
        final value = values[i];
        if (value == null) continue;
        final x = _getXPositionFromTime(candles[i].timestamp, chartRect);
        final y = _getYPositionFromPrice(value, chartRect);
        if (started) {
          path.lineTo(x, y);
        } else {
          path.moveTo(x, y);
          started = true;
        }
      }
      if (started) canvas.drawPath(path, paint..color = ema.color);
    }

    canvas.restore();
  }

  /// The channel between the bands, faintly filled, with the average as a
  /// thinner line down the middle.
  void _drawBollinger(Canvas canvas, Rect chartRect, int firstIndex, int effectiveEndIndex) {
    final bollinger = style.bollinger;
    if (bollinger == null || firstIndex == -1 || effectiveEndIndex == -1) return;

    final bands = bollingerBands(candles, bollinger.period, bollinger.deviation);
    final upper = Path();
    final lower = Path();
    final middle = Path();
    final lowerPoints = <Offset>[];
    bool started = false;

    for (int i = max(0, firstIndex - 1); i < min(candles.length, effectiveEndIndex + 1); i++) {
      final band = bands[i];
      if (band == null) continue;
      final x = _getXPositionFromTime(candles[i].timestamp, chartRect);
      final upperPoint = Offset(x, _getYPositionFromPrice(band.upper, chartRect));
      final middlePoint = Offset(x, _getYPositionFromPrice(band.middle, chartRect));
      lowerPoints.add(Offset(x, _getYPositionFromPrice(band.lower, chartRect)));
      if (started) {
        upper.lineTo(upperPoint.dx, upperPoint.dy);
        middle.lineTo(middlePoint.dx, middlePoint.dy);
      } else {
        upper.moveTo(upperPoint.dx, upperPoint.dy);
        middle.moveTo(middlePoint.dx, middlePoint.dy);
        started = true;
      }
    }
    if (!started) return;

    lower.moveTo(lowerPoints.first.dx, lowerPoints.first.dy);
    for (final point in lowerPoints.skip(1)) {
      lower.lineTo(point.dx, point.dy);
    }
    final channel = Path.from(upper);
    for (final point in lowerPoints.reversed) {
      channel.lineTo(point.dx, point.dy);
    }
    channel.close();

    canvas.save();
    canvas.clipRect(chartRect);

    canvas.drawPath(channel, Paint()..color = bollinger.color.withAlpha(20));
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..color = bollinger.color
      ..strokeWidth = 1.0;
    canvas.drawPath(upper, linePaint);
    canvas.drawPath(lower, linePaint);
    canvas.drawPath(middle, linePaint..strokeWidth = 0.6);

    canvas.restore();
  }

  /// Whether this candle's body is painted solid rather than outlined. A doji
  /// has no body to fill.
  bool _fillsBody(ChartCandle candle) {
    if (candle.close > candle.open) return style.filledUpCandles;
    if (candle.close < candle.open) return style.filledDownCandles;
    return false;
  }

  /// Gets the color of a [ChartCandle] based on price movement.
  Color _colorFromCandle(ChartCandle candle) {
    if (candle.close > candle.open) {
      return style.colors.upCandle;
    } else if (candle.close < candle.open) {
      return style.colors.downCandle;
    } else {
      return style.colors.doji;
    }
  }

  /// Draws axis labels, returning the time label format.
  String _drawAxisLabels(Canvas canvas, Rect chartRect) {
    // Price axis (vertical)
    final priceTicks = _generateNicePriceTicks(priceAxis.start, priceAxis.end, chartRect.height);
    // A hairline: the colour's alpha is what keeps the grid quiet, and a
    // thinner stroke would anti-alias it out of sight.
    final gridPaint = Paint()
      ..color = style.colors.grid
      ..strokeWidth = 1.0;

    for (final tick in priceTicks) {
      final yRatio = 1 - (tick - priceAxis.start) / (priceAxis.range);
      final y = chartRect.top + yRatio * chartRect.height;

      // grid line
      if (style.grid) {
        final g1 = Offset(chartRect.left, y);
        final g2 = Offset(chartRect.right, y);
        canvas.drawLine(g1, g2, gridPaint);
      }

      // Label
      final text = formatPrice(tick);
      final tp = TextPainter(
        text: TextSpan(text: text, style: style.labelStyle.textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(chartRect.right + style.labelStyle.labelMargin, y - tp.height / 2));
    }

    // Time axis (horizontal)
    final timeTicks = _generateNiceTimeTicks(chartRect.width);

    for (final tick in timeTicks.$1) {
      final xRatio = (tick.millisecondsSinceEpoch - timeAxis.start) / timeAxis.range;
      final x = chartRect.left + xRatio * chartRect.width;

      // grid line
      if (style.grid) {
        final g1 = Offset(x, chartRect.top);
        final g2 = Offset(x, chartRect.bottom);
        canvas.drawLine(g1, g2, gridPaint);
      }

      // Label
      final text = _formatTime(tick, timeTicks.$2);
      final tp = TextPainter(
        text: TextSpan(text: text, style: style.labelStyle.textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chartRect.bottom + style.labelStyle.labelMargin));
    }

    return timeTicks.$2;
  }

  /// Draws the crosshair and its axis-aligned labels.
  void _drawCrosshair(Canvas canvas, Offset position, ChartCandle? candle, String dateFormat, Rect chartRect) {
    final backgroundPaint = Paint()..color = style.colors.crosshairLabelBackground;
    final paint = Paint()
      ..color = style.colors.crosshair
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    double dx = position.dx;
    if (candle != null) {
      final interval = candle.endTimestamp + 1 - candle.timestamp;
      final time = _getTimeFromXPosition(x: dx, chartRect: chartRect, axis: timeAxis) + interval / 2;
      final updatedTime = (time ~/ interval) * interval;
      dx = _getXPositionFromTime(updatedTime, chartRect);
    }

    _drawDashedLine(
      canvas: canvas,
      p1: Offset(chartRect.left, position.dy),
      p2: Offset(chartRect.right, position.dy),
      pattern: [10.0, 10.0],
      paint: paint,
    );
    _drawDashedLine(
      canvas: canvas,
      p1: Offset(dx, chartRect.top),
      p2: Offset(dx, chartRect.bottom),
      pattern: [10.0, 10.0],
      paint: paint,
    );

    // Draw time label
    final ms = _getTimeFromXPosition(x: dx, chartRect: chartRect, axis: timeAxis);
    final timeMs = DateTime.fromMillisecondsSinceEpoch(ms);
    final timeText = _formatTime(timeMs, dateFormat);
    final timePainter = TextPainter(
      text: TextSpan(
        text: timeText,
        style: TextStyle(color: style.colors.crosshairLabelText),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final timeRect = Rect.fromLTWH(
      dx - timePainter.width / 2 - style.labelStyle.padding,
      chartRect.bottom + style.labelStyle.labelMargin - style.labelStyle.padding,
      timePainter.width + style.labelStyle.padding * 2,
      timePainter.height + style.labelStyle.padding * 2,
    );
    canvas.drawRect(timeRect, backgroundPaint);
    timePainter.paint(canvas, Offset(dx - timePainter.width / 2, chartRect.bottom + style.labelStyle.labelMargin));

    // Draw price label (below vertical line)
    final price = _getPriceFromYPosition(y: position.dy, chartRect: chartRect, axis: priceAxis);
    final priceText = formatPrice(price);
    final pricePainter = TextPainter(
      text: TextSpan(
        text: priceText,
        style: TextStyle(color: style.colors.crosshairLabelText),
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

  /// Generates rounded price ticks based on chart height.
  List<double> _generateNicePriceTicks(double start, double end, double chartHeight) {
    final range = end - start;
    final approxTicks = (chartHeight / style.labelStyle.minSpacingPxPriceAxis).floor().clamp(2, 100);
    final rawStep = range / approxTicks;
    final step = _niceStep(rawStep);
    final firstStepIndex = (start / step).ceil();
    final lastStepIndex = (end / step).floor();
    final ticks = <double>[];
    for (int i = firstStepIndex; i <= lastStepIndex; i++) {
      final rawTick = i * step;
      ticks.add(_cleanFloat(rawTick));
    }
    return ticks;
  }

  double _cleanFloat(double value) {
    return double.parse(value.toStringAsFixed(_maxTickCleanupDecimals));
  }

  /// Rounds raw step to a human-friendly value.
  double _niceStep(double raw) {
    final exp = (log(raw) / ln10).floor();
    final base = raw / pow(10, exp);
    final rounded = base < 1.5
        ? 1
        : base < 3
        ? 2
        : base < 7
        ? 5
        : 10;
    return rounded * pow(10, exp).toDouble();
  }

  /// Generates rounded time ticks and the format string to use.
  (List<DateTime>, String) _generateNiceTimeTicks(double chartWidth) {
    final rangeMs = timeAxis.range;
    final approxTicks = (chartWidth / style.labelStyle.minSpacingPxTimeAxis).floor().clamp(2, 50);
    final rawStep = rangeMs ~/ approxTicks;

    final timestep = TimeSteps.values.firstWhere(
      (e) => rawStep < e.duration.inMilliseconds,
      orElse: () => TimeSteps.values.last,
    );

    final ticks = <DateTime>[];
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timeAxis.start);
    if (timestep.duration.inDays < 2) {
      final offset = date.timeZoneOffset;
      final firstTickMs =
          ((timeAxis.start + offset.inMilliseconds) / timestep.duration.inMilliseconds).ceil() *
              timestep.duration.inMilliseconds -
          offset.inMilliseconds;
      for (int ms = firstTickMs; ms <= timeAxis.end; ms += timestep.duration.inMilliseconds) {
        ticks.add(DateTime.fromMillisecondsSinceEpoch(ms));
      }
    } else {
      final endDate = DateTime.fromMillisecondsSinceEpoch(timeAxis.end);
      if (timestep.duration.inDays < 25) {
        date = date.add(const Duration(days: 1));
        int day = ((date.day - 1) / timestep.duration.inDays).ceil() * timestep.duration.inDays + 1;
        DateTime currDate = DateTime(date.year, date.month, day);
        while (true) {
          if (currDate.month != date.month) {
            currDate = DateTime(currDate.year, currDate.month);
          }
          if (currDate.isBefore(endDate)) {
            if (ticks.isNotEmpty && currDate.difference(ticks.last) < timestep.duration) {
              ticks.removeLast();
            }
            ticks.add(currDate);
          } else {
            break;
          }
          date = currDate;
          currDate = currDate.add(timestep.duration);
        }
      } else if (timestep.duration.inDays < 365) {
        date = DateTime(date.year, date.month + 1);
        int nbMonth = timestep.duration.inDays ~/ 30;
        int month = ((date.month - 1) / nbMonth).ceil() * nbMonth + 1;
        DateTime currDate = DateTime(date.year, month);
        while (true) {
          if (currDate.year != date.year) {
            currDate = DateTime(currDate.year);
          }
          if (currDate.isBefore(endDate)) {
            ticks.add(currDate);
          } else {
            break;
          }
          date = currDate;
          currDate = DateTime(currDate.year, currDate.month + nbMonth);
        }
      } else {
        date = DateTime(date.year + 1);
        int nbYears = timestep.duration.inDays ~/ 365;
        int year = (date.year / nbYears).ceil() * nbYears;
        DateTime currDate = DateTime(year);
        while (true) {
          if (currDate.isBefore(endDate)) {
            ticks.add(currDate);
          } else {
            break;
          }
          date = currDate;
          currDate = DateTime(currDate.year + nbYears);
        }
      }
    }
    return (ticks, timestep.format);
  }

  /// Formats a time label using intl.
  String _formatTime(DateTime dt, String dateFormat) {
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

  /// Draws a dashed line from [p1] to [p2] with given dash [pattern].
  void _drawDashedLine({
    required Canvas canvas,
    required Offset p1,
    required Offset p2,
    required List<double> pattern,
    required Paint paint,
  }) {
    assert(pattern.length.isEven);
    final distance = (p2 - p1).distance;
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

  /// Converts a price to Y coordinate.
  double _getYPositionFromPrice(double price, Rect chartRect) {
    return chartRect.top + (1 - (price - priceAxis.start) / priceAxis.range) * chartRect.height;
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
    final yRatio = 1 - (y - chartRect.top) / chartRect.height;
    return axis.start + axis.range * yRatio;
  }

  @override
  bool shouldRepaint(covariant ChartPainter oldDelegate) {
    return oldDelegate.crosshairPosition != crosshairPosition ||
        oldDelegate.candles != candles ||
        oldDelegate.lines != lines ||
        oldDelegate.orderLines != orderLines ||
        oldDelegate.positions != positions ||
        oldDelegate.style != style ||
        oldDelegate.priceAxis != priceAxis ||
        oldDelegate.timeAxis != timeAxis;
  }
}

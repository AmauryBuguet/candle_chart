import 'dart:math';

import 'package:flutter/painting.dart';

import '../internal/drawing_geometry.dart';
import '../models/axis.dart';
import '../models/chart_candle.dart';
import '../models/chart_style.dart';

/// Draws the visible candles into the price pane, as candlesticks or as a
/// line through their closes.
class CandlePainter {
  CandlePainter({
    required this.canvas,
    required this.projection,
    required this.candles,
    required this.firstIndex,
    required this.endIndex,
    required this.style,
    required this.priceAxis,
    required this.timeAxis,
  });

  final Canvas canvas;

  /// The price pane's mapping.
  final DrawingProjection projection;
  final List<ChartCandle> candles;

  /// The visible candles, plus one either side.
  final int firstIndex;
  final int endIndex;
  final ChartStyle style;
  final PriceAxis priceAxis;
  final TimeAxis timeAxis;

  Rect get _rect => projection.rect;

  /// The closes joined up, the visible ones plus one either side.
  void drawCloseLine() {
    if (firstIndex == -1 || endIndex == -1) return;
    canvas.save();
    canvas.clipRect(_rect);
    final path = Path();
    for (int i = max(0, firstIndex - 1); i < min(candles.length, endIndex + 1); i++) {
      final x = projection.xForTime(candles[i].timestamp);
      final y = projection.yForPrice(candles[i].close);
      if (i == max(0, firstIndex - 1)) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..color = style.colors.line,
    );
    canvas.restore();
  }

  /// Renders all visible candles.
  void drawCandles() {
    if (firstIndex == -1 || endIndex == -1) return;

    // Use the first visible candle to determine the time difference
    final diffTs = candles[firstIndex].endTimestamp - candles[firstIndex].timestamp;
    final double candleDemiWidth = _rect.width * 0.35 * diffTs / timeAxis.range;

    canvas.save();
    canvas.clipRect(_rect);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final bodyPaint = Paint()..style = PaintingStyle.fill;

    for (int i = firstIndex; i < endIndex; i++) {
      final candle = candles[i];

      if (candle.low > priceAxis.end || candle.high < priceAxis.start) {
        continue;
      }

      paint.color = _colorFromCandle(candle);
      bodyPaint.color = paint.color;

      final x = projection.xForTime(candle.timestamp);
      final openY = projection.yForPrice(candle.open);
      final closeY = projection.yForPrice(candle.close);
      final highY = projection.yForPrice(candle.high);
      final lowY = projection.yForPrice(candle.low);

      final top = min(openY, closeY);
      final bottom = max(openY, closeY);

      canvas.drawLine(Offset(x, highY), Offset(x, top), paint);
      canvas.drawLine(Offset(x, bottom), Offset(x, lowY), paint);

      final bodyRect = Rect.fromLTWH(x - candleDemiWidth, top, candleDemiWidth * 2, max(1.0, bottom - top));
      canvas.drawRect(bodyRect, _fillsBody(candle) ? bodyPaint : paint);
    }

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
}

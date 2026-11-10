import 'dart:math';

import 'package:flutter/widgets.dart';

import '../internal/drawing_geometry.dart';
import '../models/axis.dart';
import '../models/chart_candle.dart';
import '../models/chart_style.dart';

/// Draws the forming candle's price in the right gutter, at its height and
/// in the candle's colour, with the time left before it closes under it.
class LastPricePainter {
  LastPricePainter({
    required this.canvas,
    required this.projection,
    required this.style,
    required this.priceAxis,
    required this.formatPrice,
    required this.right,
  });

  final Canvas canvas;

  /// The price pane's mapping.
  final DrawingProjection projection;
  final ChartStyle style;
  final PriceAxis priceAxis;
  final String Function(double price) formatPrice;

  /// The canvas's right edge, which the label stays within.
  final double right;

  /// Nothing while the price is out of view.
  void draw(ChartCandle candle, String? countdown) {
    final price = candle.close;
    if (price < priceAxis.start || price > priceAxis.end) return;
    final colors = style.colors;
    final background = price > candle.open
        ? colors.upCandle
        : price < candle.open
        ? colors.downCandle
        : colors.doji;
    // Candle colours are the host's: the text takes whichever tone reads on them.
    final textColor = background.computeLuminance() > 0.4 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final labelStyle = style.labelStyle;
    TextPainter label(String text) => TextPainter(
      text: TextSpan(
        text: text,
        style: labelStyle.textStyle.copyWith(color: textColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pricePainter = label(formatPrice(price));
    final countdownPainter = countdown == null ? null : label(countdown);
    final width = max(pricePainter.width, countdownPainter?.width ?? 0);
    final rect = projection.rect;
    // A countdown wider than the gutter spills over the plot, not off the canvas.
    final left = min(rect.right + labelStyle.labelMargin, right - width - labelStyle.padding);
    final top = projection.yForPrice(price) - pricePainter.height / 2;
    canvas.drawRect(
      Rect.fromLTWH(
        left - labelStyle.padding,
        top - labelStyle.padding,
        width + labelStyle.padding * 2,
        pricePainter.height + (countdownPainter?.height ?? 0) + labelStyle.padding * 2,
      ),
      Paint()..color = background,
    );
    pricePainter.paint(canvas, Offset(left, top));
    countdownPainter?.paint(canvas, Offset(left, top + pricePainter.height));
  }
}

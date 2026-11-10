import 'dart:math';

import 'package:flutter/painting.dart';

import '../internal/drawing_geometry.dart';
import '../models/axis.dart';
import '../models/chart_candle.dart';
import '../models/chart_indicator.dart';

/// The price rows a profile is binned into, over the visible price range.
const int _profileRows = 100;

/// A profile's widest bar, as a share of the price pane's width.
const double _profileWidth = 0.30;

/// How strongly the order book profile's colours show.
const double _bookProfileOpacity = 0.4;

/// Draws the price pane's horizontal profiles: the visible range's volume
/// and the order book's resting size, against their side of the pane.
class ProfilePainter {
  ProfilePainter({required this.canvas, required this.projection, required this.priceAxis});

  final Canvas canvas;

  /// The price pane's mapping.
  final DrawingProjection projection;
  final PriceAxis priceAxis;

  /// Draws the Visible Range Volume Profile against its side of the chart.
  void drawVolumeProfile(List<ChartCandle> candles, int firstIndex, int effectiveEndIndex, ChartVolumeProfile profile) {
    final chartRect = projection.rect;
    if (firstIndex == -1 || effectiveEndIndex == -1 || priceAxis.range <= 0) return;

    // 1. Setup Price Bins
    const int binsCount = _profileRows;
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

    final double maxBarWidth = chartRect.width * _profileWidth;

    final Paint vpvrPaint = Paint()
      ..color = profile.color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < binsCount; i++) {
      if (volumeBins[i] == 0) continue;

      final double barWidth = (volumeBins[i] / maxVol) * maxBarWidth;
      final double priceBottom = priceAxis.start + i * binPriceHeight;
      final double priceTop = priceBottom + binPriceHeight;

      final double yBottom = projection.yForPrice(priceBottom);
      final double yTop = projection.yForPrice(priceTop);

      final Rect barRect = _profileBar(profile.side, 0, barWidth, yTop, yBottom);

      canvas.drawRect(barRect, vpvrPaint);
    }

    // 5. Draw Point of Control (POC) Line
    if (pocIndex != -1) {
      // Calculate the exact price bounds for the POC bin
      final double priceBottom = priceAxis.start + pocIndex * binPriceHeight;
      final double priceTop = priceBottom + binPriceHeight;

      // Convert prices to Y coordinates on the canvas
      final double yBottom = projection.yForPrice(priceBottom);
      final double yTop = projection.yForPrice(priceTop);

      // Create a rectangle that spans the max bar width and matches the bin's exact height
      final Rect pocRect = _profileBar(profile.side, 0, maxBarWidth, yTop, yBottom);

      final Paint pocPaint = Paint()
        ..color = profile.pocColor
        ..style = PaintingStyle.fill;
      canvas.drawRect(pocRect, pocPaint);
    }

    canvas.restore();
  }

  /// Draws the order book profile: each level's size spread over the rows its
  /// range covers, bids then asks stacked out from the profile's side.
  void drawOrderBookProfile(ChartOrderBookProfile profile) {
    final chartRect = projection.rect;
    if (priceAxis.range <= 0) return;
    final rowHeight = priceAxis.range / _profileRows;

    List<double> rows(List<ChartBookLevel> levels) {
      final sizes = List.filled(_profileRows, 0.0);
      for (final level in levels) {
        final span = level.high - level.low;
        if (level.size <= 0) continue;
        if (span <= 0) {
          final row = ((level.low - priceAxis.start) / rowHeight).floor();
          if (row >= 0 && row < _profileRows) sizes[row] += level.size;
          continue;
        }
        final first = max(0, ((level.low - priceAxis.start) / rowHeight).floor());
        final last = min(_profileRows - 1, ((level.high - priceAxis.start) / rowHeight).floor());
        for (var row = first; row <= last; row++) {
          final rowLow = priceAxis.start + row * rowHeight;
          final overlap = min(level.high, rowLow + rowHeight) - max(level.low, rowLow);
          if (overlap > 0) sizes[row] += level.size * overlap / span;
        }
      }
      return sizes;
    }

    final bids = rows(profile.bidColor == null ? const [] : profile.bids);
    final asks = rows(profile.askColor == null ? const [] : profile.asks);
    var largest = 0.0;
    for (var row = 0; row < _profileRows; row++) {
      largest = max(largest, bids[row] + asks[row]);
    }
    if (largest == 0) return;

    canvas.save();
    canvas.clipRect(chartRect);
    final maxWidth = chartRect.width * _profileWidth;
    Paint? paintOf(Color? color) =>
        color == null ? null : (Paint()..color = color.withValues(alpha: color.a * _bookProfileOpacity));
    final bidPaint = paintOf(profile.bidColor);
    final askPaint = paintOf(profile.askColor);
    for (var row = 0; row < _profileRows; row++) {
      if (bids[row] + asks[row] == 0) continue;
      final rowLow = priceAxis.start + row * rowHeight;
      final yBottom = projection.yForPrice(rowLow);
      final yTop = projection.yForPrice(rowLow + rowHeight);
      final bidWidth = bids[row] / largest * maxWidth;
      final askWidth = asks[row] / largest * maxWidth;
      if (bidPaint != null && bidWidth > 0) {
        canvas.drawRect(_profileBar(profile.side, 0, bidWidth, yTop, yBottom), bidPaint);
      }
      if (askPaint != null && askWidth > 0) {
        canvas.drawRect(_profileBar(profile.side, bidWidth, askWidth, yTop, yBottom), askPaint);
      }
    }
    canvas.restore();
  }

  /// A profile's bar: [width] wide, starting [offset] in from [side].
  Rect _profileBar(ChartProfileSide side, double offset, double width, double top, double bottom) {
    final chartRect = projection.rect;
    return switch (side) {
      ChartProfileSide.left => Rect.fromLTRB(chartRect.left + offset, top, chartRect.left + offset + width, bottom),
      ChartProfileSide.right => Rect.fromLTRB(chartRect.right - offset - width, top, chartRect.right - offset, bottom),
    };
  }
}

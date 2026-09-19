import 'dart:math';

import 'package:collection/collection.dart';

import '../models/axis.dart';
import '../models/chart_candle.dart';

/// Pure price-axis state and fit/pan/zoom math. No framework dependency.
class PriceAxisEngine {
  PriceAxis axis = const PriceAxis();
  bool anchored = true;

  /// Refits [axis] to the candles visible within [timeAxis]. No-op while
  /// [anchored] is false (the user has manually panned/zoomed the price axis).
  void recompute({
    required List<ChartCandle> candles,
    required TimeAxis timeAxis,
    required double priceMargin,
  }) {
    if (!anchored) return;

    var firstIndex = candles.indexWhere((e) => e.timestamp >= timeAxis.start);
    if (firstIndex == -1) {
      axis = const PriceAxis();
      return;
    } else if (firstIndex > 0) {
      firstIndex--;
    }
    var lastIndex = candles.indexWhere((e) => e.timestamp >= timeAxis.end, firstIndex);
    if (lastIndex != -1 && lastIndex < candles.length - 1) {
      lastIndex++;
    }
    final sublist = candles.sublist(firstIndex, lastIndex != -1 ? lastIndex : null);
    final minValue = sublist.map((e) => e.low).min;
    final maxValue = sublist.map((e) => e.high).max;
    var offset = (maxValue - minValue) * priceMargin;
    if (offset == 0) {
      offset = minValue * 0.01;
    }
    axis = PriceAxis(start: minValue - offset, end: maxValue + offset);
  }

  void setAnchored({required List<ChartCandle> candles, required TimeAxis timeAxis, required double priceMargin}) {
    if (!anchored) {
      anchored = true;
      recompute(candles: candles, timeAxis: timeAxis, priceMargin: priceMargin);
    }
  }

  /// Zooms the axis about its middle by a pointer moved [dy] pixels over a
  /// pane [height] tall: on a log scale the ends move by the same ratio
  /// rather than the same amount.
  void scaleBy(double dy, double height, {required bool logScale}) {
    anchored = false;
    if (logScale) {
      final factor = _logFactor(dy, height);
      axis = PriceAxis(start: axis.start / factor, end: axis.end * factor);
    } else {
      final value = -dy * axis.range / height;
      if (axis.range - 2 * value <= 0) return;
      axis = axis.copyWith(start: axis.start + value, end: axis.end - value);
    }
  }

  /// Follows a pointer moved [dy] pixels, once the axis has been unanchored
  /// by a zoom; an anchored axis refits to the candles instead.
  void panBy(double dy, double height, {required bool logScale}) {
    if (anchored) return;
    if (logScale) {
      final factor = _logFactor(dy, height);
      axis = PriceAxis(start: axis.start * factor, end: axis.end * factor);
    } else {
      final value = dy * axis.range / height;
      axis = axis.copyWith(start: axis.start + value, end: axis.end + value);
    }
  }

  /// The ratio a price under the pointer moves by when the pointer moves
  /// [dy] pixels down a log-scaled pane [height] tall.
  double _logFactor(double dy, double height) {
    final start = max(axis.start, 1e-12);
    final end = max(axis.end, start * 1.0001);
    return exp(dy / height * (log(end) - log(start)));
  }
}

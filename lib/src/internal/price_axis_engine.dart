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

  void scale(double value) {
    anchored = false;
    axis = axis.copyWith(start: axis.start + value, end: axis.end - value);
  }

  void pan(double value) {
    axis = axis.copyWith(start: axis.start + value, end: axis.end + value);
  }

  void panIfUnAnchored(double value) {
    if (!anchored) {
      pan(value);
    }
  }
}

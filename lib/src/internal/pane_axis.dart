import 'dart:math';

import '../models/axis.dart';
import '../models/chart_candle.dart';
import 'indicator_render.dart';

/// The value axis of a pane: its fixed range when the indicator has one,
/// otherwise the visible values of its series with a little room, and a
/// histogram always keeping its zero line in view.
PriceAxis fitPaneAxis({
  required IndicatorRender render,
  required List<ChartCandle> candles,
  required TimeAxis timeAxis,
}) {
  final fixed = render.fixedRange;
  if (fixed != null) return PriceAxis(start: fixed.$1, end: fixed.$2);

  var first = candles.indexWhere((c) => c.timestamp >= timeAxis.start);
  if (first == -1) return const PriceAxis();
  if (first > 0) first--;
  var last = candles.indexWhere((c) => c.timestamp >= timeAxis.end, first);
  if (last == -1) last = candles.length;

  var low = double.infinity;
  var high = double.negativeInfinity;
  for (final series in render.series) {
    for (var i = first; i < last; i++) {
      final shifted = i - series.offset;
      if (shifted < 0 || shifted >= series.values.length) continue;
      final value = series.values[shifted];
      if (value == null) continue;
      low = min(low, value);
      high = max(high, value);
    }
    if (series.kind == SeriesKind.histogram) {
      low = min(low, 0);
      high = max(high, 0);
    }
  }
  for (final level in render.levels) {
    low = min(low, level);
    high = max(high, level);
  }
  if (low == double.infinity) return const PriceAxis();
  var room = (high - low) * 0.1;
  if (room == 0) room = low.abs() * 0.01;
  if (room == 0) room = 1;
  // Bars grow from zero; an axis starting under it would float them.
  return PriceAxis(start: low == 0 ? 0 : low - room, end: high + room);
}

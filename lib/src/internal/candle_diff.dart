import 'dart:math';

import '../models/chart_candle.dart';

/// The index of the first candle that differs between [previous] and
/// [next] — the shorter one's length when the other starts with it — or
/// `null` when they hold the same candles.
///
/// Every candle is compared, field by field rather than through `==`, so a
/// change anywhere is found without the cost of a deep comparison.
int? firstChangedCandle(List<ChartCandle> previous, List<ChartCandle> next) {
  if (identical(previous, next)) return null;
  final length = min(previous.length, next.length);
  for (var i = 0; i < length; i++) {
    if (!_same(previous[i], next[i])) return i;
  }
  return previous.length == next.length ? null : length;
}

bool _same(ChartCandle a, ChartCandle b) =>
    identical(a, b) ||
    (a.timestamp == b.timestamp &&
        a.endTimestamp == b.endTimestamp &&
        a.open == b.open &&
        a.high == b.high &&
        a.low == b.low &&
        a.close == b.close &&
        a.volume == b.volume);

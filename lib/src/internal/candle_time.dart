import 'dart:math';

import '../models/chart_candle.dart';

/// The open time of the candle [time] falls in, so a point set on a finer
/// interval sits on the candle that holds it, as the crosshair does. Past
/// either end of [candles] it steps by the interval of the candle there.
int candleTimeOf(int time, List<ChartCandle> candles) {
  if (candles.isEmpty) return time;
  final first = candles.first;
  if (time < first.timestamp) {
    final interval = _span(first);
    if (interval <= 0) return time;
    return first.timestamp - (first.timestamp - time + interval - 1) ~/ interval * interval;
  }
  final last = candles.last;
  if (time >= last.timestamp) {
    final interval = _span(last);
    if (interval <= 0) return time;
    return last.timestamp + (time - last.timestamp) ~/ interval * interval;
  }
  return candles[_indexAt(time, candles)].timestamp;
}

/// The open time of the candle nearest [time]: the one it falls in, or the
/// next once past its middle. The crosshair and drawings snap to it, so they
/// follow the candles even when those do not divide time evenly, as calendar
/// weeks and months do not. In a hole in [candles] it steps by the candle
/// before the hole, as past either end.
int nearestCandleTime(int time, List<ChartCandle> candles) {
  if (candles.isEmpty) return time;
  final (open, next) = _slot(time, candles);
  return time - open < next - time ? open : next;
}

/// The open and the end of the slot [time] falls in: a candle, or one step
/// of the grid where there is none.
(int, int) _slot(int time, List<ChartCandle> candles) {
  final first = candles.first, last = candles.last;
  if (time < first.timestamp || time >= last.timestamp) {
    final open = candleTimeOf(time, candles);
    return (open, open + _span(time < first.timestamp ? first : last));
  }
  final index = _indexAt(time, candles);
  final candle = candles[index];
  final next = candles[index + 1].timestamp;
  final span = _span(candle);
  if (span <= 0) return (candle.timestamp, next);
  final open = candle.timestamp + (time - candle.timestamp) ~/ span * span;
  return (open, min(open + span, next));
}

int _span(ChartCandle candle) => candle.endTimestamp + 1 - candle.timestamp;

/// The index of the last candle opening at or before [time], which falls
/// within [candles].
int _indexAt(int time, List<ChartCandle> candles) {
  var low = 0, high = candles.length - 1;
  while (low < high) {
    final mid = (low + high + 1) ~/ 2;
    if (candles[mid].timestamp <= time) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return low;
}

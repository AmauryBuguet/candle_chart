import '../models/chart_candle.dart';

/// The open time of the candle [time] falls in, so a point set on a finer
/// interval sits on the candle that holds it, as the crosshair does. Past
/// either end of [candles] it steps by the interval of the candle there.
int candleTimeOf(int time, List<ChartCandle> candles) {
  if (candles.isEmpty) return time;
  final first = candles.first;
  if (time < first.timestamp) {
    final interval = first.endTimestamp + 1 - first.timestamp;
    if (interval <= 0) return time;
    return first.timestamp - (first.timestamp - time + interval - 1) ~/ interval * interval;
  }
  final last = candles.last;
  if (time >= last.timestamp) {
    final interval = last.endTimestamp + 1 - last.timestamp;
    if (interval <= 0) return time;
    return last.timestamp + (time - last.timestamp) ~/ interval * interval;
  }
  var low = 0, high = candles.length - 1;
  while (low < high) {
    final mid = (low + high + 1) ~/ 2;
    if (candles[mid].timestamp <= time) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return candles[low].timestamp;
}

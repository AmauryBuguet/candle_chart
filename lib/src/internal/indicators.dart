import 'dart:math';

import '../models/chart_candle.dart';

/// The EMA of the closes, one value per candle: `null` until [period] closes
/// have accrued, seeded with their simple average, then smoothed with the
/// usual `2 / (period + 1)` weight.
List<double?> exponentialMovingAverage(List<ChartCandle> candles, int period) {
  final values = List<double?>.filled(candles.length, null);
  if (period <= 0 || candles.length < period) return values;

  double sum = 0;
  for (var i = 0; i < period; i++) {
    sum += candles[i].close;
  }
  var value = sum / period;
  values[period - 1] = value;

  final weight = 2 / (period + 1);
  for (var i = period; i < candles.length; i++) {
    value += (candles[i].close - value) * weight;
    values[i] = value;
  }
  return values;
}

/// One Bollinger band per candle: `null` until [period] closes have accrued,
/// then the simple average with a band [deviation] population standard
/// deviations either side of it.
List<({double middle, double upper, double lower})?> bollingerBands(
  List<ChartCandle> candles,
  int period,
  double deviation,
) {
  final bands = List<({double middle, double upper, double lower})?>.filled(candles.length, null);
  if (period <= 1 || candles.length < period) return bands;

  double sum = 0;
  double squares = 0;
  for (var i = 0; i < candles.length; i++) {
    final close = candles[i].close;
    sum += close;
    squares += close * close;
    if (i >= period) {
      final gone = candles[i - period].close;
      sum -= gone;
      squares -= gone * gone;
    }
    if (i < period - 1) continue;

    final mean = sum / period;
    final variance = max(0, squares / period - mean * mean);
    final width = sqrt(variance) * deviation;
    bands[i] = (middle: mean, upper: mean + width, lower: mean - width);
  }
  return bands;
}

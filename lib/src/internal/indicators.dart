import 'dart:math';

import '../models/chart_candle.dart';

/// The simple average of the last [period] closes, `null` until that many
/// have accrued.
List<double?> simpleMovingAverage(List<ChartCandle> candles, int period) =>
    _rollingMean([for (final c in candles) c.close], period);

/// The EMA of the closes, one value per candle: `null` until [period] closes
/// have accrued, seeded with their simple average, then smoothed with the
/// usual `2 / (period + 1)` weight.
List<double?> exponentialMovingAverage(List<ChartCandle> candles, int period) =>
    _ema([for (final c in candles) c.close], period);

/// The weighted average of the last [period] closes, the most recent
/// weighing [period] and the oldest 1.
List<double?> weightedMovingAverage(List<ChartCandle> candles, int period) {
  final values = List<double?>.filled(candles.length, null);
  if (period <= 0 || candles.length < period) return values;
  final denominator = period * (period + 1) / 2;
  for (var i = period - 1; i < candles.length; i++) {
    double sum = 0;
    for (var k = 0; k < period; k++) {
      sum += candles[i - k].close * (period - k);
    }
    values[i] = sum / denominator;
  }
  return values;
}

/// The volume-weighted average of the typical price since the first candle
/// of each UTC day; a candle with no volume carries the running value.
List<double?> volumeWeightedAveragePrice(List<ChartCandle> candles) {
  final values = List<double?>.filled(candles.length, null);
  double priceVolume = 0;
  double volume = 0;
  int? day;
  for (var i = 0; i < candles.length; i++) {
    final candle = candles[i];
    final candleDay = candle.timestamp ~/ Duration.millisecondsPerDay;
    if (candleDay != day) {
      day = candleDay;
      priceVolume = 0;
      volume = 0;
    }
    final typical = (candle.high + candle.low + candle.close) / 3;
    priceVolume += typical * candle.volume;
    volume += candle.volume;
    values[i] = volume > 0 ? priceVolume / volume : (i > 0 ? values[i - 1] : null);
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

/// Wilder's RSI of the closes: `null` until [period] changes have accrued,
/// the first value from their plain averages, then smoothed with weight
/// `1 / period`.
List<double?> relativeStrengthIndex(List<ChartCandle> candles, int period) {
  final values = List<double?>.filled(candles.length, null);
  if (period <= 0 || candles.length <= period) return values;

  double gains = 0;
  double losses = 0;
  for (var i = 1; i <= period; i++) {
    final change = candles[i].close - candles[i - 1].close;
    if (change > 0) {
      gains += change;
    } else {
      losses -= change;
    }
  }
  var averageGain = gains / period;
  var averageLoss = losses / period;
  values[period] = _rsi(averageGain, averageLoss);

  for (var i = period + 1; i < candles.length; i++) {
    final change = candles[i].close - candles[i - 1].close;
    averageGain = (averageGain * (period - 1) + max(change, 0)) / period;
    averageLoss = (averageLoss * (period - 1) + max(-change, 0)) / period;
    values[i] = _rsi(averageGain, averageLoss);
  }
  return values;
}

double _rsi(double averageGain, double averageLoss) {
  if (averageLoss == 0) return 100;
  return 100 - 100 / (1 + averageGain / averageLoss);
}

/// MACD: the fast EMA less the slow one, its EMA as the signal, and the gap
/// between the two as the histogram. The signal seeds on the first
/// [signalPeriod] MACD values, as the EMAs seed on their first closes.
List<({double macd, double signal, double histogram})?> macd(
  List<ChartCandle> candles,
  int fastPeriod,
  int slowPeriod,
  int signalPeriod,
) {
  final result = List<({double macd, double signal, double histogram})?>.filled(candles.length, null);
  final fast = exponentialMovingAverage(candles, fastPeriod);
  final slow = exponentialMovingAverage(candles, slowPeriod);
  final line = <double>[];
  for (var i = 0; i < candles.length; i++) {
    final f = fast[i];
    final s = slow[i];
    if (f == null || s == null) continue;
    line.add(f - s);
  }
  final signal = _ema(line, signalPeriod);
  final offset = candles.length - line.length;
  for (var k = 0; k < line.length; k++) {
    final s = signal[k];
    if (s == null) continue;
    result[offset + k] = (macd: line[k], signal: s, histogram: line[k] - s);
  }
  return result;
}

/// The stochastic oscillator: raw %K as where the close sits in the last
/// [kPeriod] candles' range, smoothed over [kSmoothing] candles, and %D as
/// its [dPeriod] average.
List<({double k, double d})?> stochastic(List<ChartCandle> candles, int kPeriod, int kSmoothing, int dPeriod) {
  final result = List<({double k, double d})?>.filled(candles.length, null);
  if (candles.length < kPeriod) return result;

  final raw = List<double?>.filled(candles.length, null);
  for (var i = kPeriod - 1; i < candles.length; i++) {
    double highest = double.negativeInfinity;
    double lowest = double.infinity;
    for (var k = i - kPeriod + 1; k <= i; k++) {
      highest = max(highest, candles[k].high);
      lowest = min(lowest, candles[k].low);
    }
    final range = highest - lowest;
    raw[i] = range == 0 ? 50 : (candles[i].close - lowest) / range * 100;
  }
  final smoothed = _rollingMeanNullable(raw, kSmoothing);
  final d = _rollingMeanNullable(smoothed, dPeriod);
  for (var i = 0; i < candles.length; i++) {
    final kValue = smoothed[i];
    final dValue = d[i];
    if (kValue == null || dValue == null) continue;
    result[i] = (k: kValue, d: dValue);
  }
  return result;
}

/// Ichimoku's five lines, each indexed by the candle it is computed on —
/// the leading spans are meant to be drawn [ChartIchimoku.displacement]
/// candles ahead and the lagging span as many behind, which is the
/// painter's business, not this one's.
List<({double conversion, double base, double spanA, double spanB})?> ichimoku(
  List<ChartCandle> candles,
  int conversionPeriod,
  int basePeriod,
  int spanPeriod,
) {
  final result = List<({double conversion, double base, double spanA, double spanB})?>.filled(candles.length, null);
  final conversion = _midpoint(candles, conversionPeriod);
  final base = _midpoint(candles, basePeriod);
  final spanB = _midpoint(candles, spanPeriod);
  for (var i = 0; i < candles.length; i++) {
    final c = conversion[i];
    final b = base[i];
    final sb = spanB[i];
    if (c == null || b == null || sb == null) continue;
    result[i] = (conversion: c, base: b, spanA: (c + b) / 2, spanB: sb);
  }
  return result;
}

/// Wilder's average true range: `null` until [period] ranges have accrued,
/// the first value their plain average, then smoothed with weight
/// `1 / period`.
List<double?> averageTrueRange(List<ChartCandle> candles, int period) {
  final values = List<double?>.filled(candles.length, null);
  if (period <= 0 || candles.length < period) return values;
  final ranges = <double>[];
  for (var i = 0; i < candles.length; i++) {
    final candle = candles[i];
    if (i == 0) {
      ranges.add(candle.high - candle.low);
      continue;
    }
    final previousClose = candles[i - 1].close;
    ranges.add(
      max(candle.high - candle.low, max((candle.high - previousClose).abs(), (candle.low - previousClose).abs())),
    );
  }
  double sum = 0;
  for (var i = 0; i < period; i++) {
    sum += ranges[i];
  }
  var atr = sum / period;
  values[period - 1] = atr;
  for (var i = period; i < candles.length; i++) {
    atr = (atr * (period - 1) + ranges[i]) / period;
    values[i] = atr;
  }
  return values;
}

/// SuperTrend: the ATR band the price is trailing, and which side of it the
/// market is on. `up` is true while the close last broke above the upper
/// band, and the value is then the lower band, ratcheting up.
List<({double value, bool up})?> superTrend(List<ChartCandle> candles, int period, double multiplier) {
  final result = List<({double value, bool up})?>.filled(candles.length, null);
  final atr = averageTrueRange(candles, period);
  double? upperBand;
  double? lowerBand;
  var up = true;
  for (var i = 0; i < candles.length; i++) {
    final range = atr[i];
    if (range == null) continue;
    final candle = candles[i];
    final middle = (candle.high + candle.low) / 2;
    var upper = middle + multiplier * range;
    var lower = middle - multiplier * range;
    final previousClose = i > 0 ? candles[i - 1].close : candle.close;
    if (lowerBand != null && !(lower > lowerBand || previousClose < lowerBand)) lower = lowerBand;
    if (upperBand != null && !(upper < upperBand || previousClose > upperBand)) upper = upperBand;
    if (upperBand != null && lowerBand != null) {
      if (up && candle.close < lowerBand) {
        up = false;
      } else if (!up && candle.close > upperBand) {
        up = true;
      }
    }
    upperBand = upper;
    lowerBand = lower;
    result[i] = (value: up ? lower : upper, up: up);
  }
  return result;
}

List<double?> _midpoint(List<ChartCandle> candles, int period) {
  final values = List<double?>.filled(candles.length, null);
  for (var i = period - 1; i < candles.length; i++) {
    double highest = double.negativeInfinity;
    double lowest = double.infinity;
    for (var k = i - period + 1; k <= i; k++) {
      highest = max(highest, candles[k].high);
      lowest = min(lowest, candles[k].low);
    }
    values[i] = (highest + lowest) / 2;
  }
  return values;
}

List<double?> _ema(List<double> values, int period) {
  final result = List<double?>.filled(values.length, null);
  if (period <= 0 || values.length < period) return result;

  double sum = 0;
  for (var i = 0; i < period; i++) {
    sum += values[i];
  }
  var value = sum / period;
  result[period - 1] = value;

  final weight = 2 / (period + 1);
  for (var i = period; i < values.length; i++) {
    value += (values[i] - value) * weight;
    result[i] = value;
  }
  return result;
}

List<double?> _rollingMean(List<double> values, int period) {
  final result = List<double?>.filled(values.length, null);
  if (period <= 0 || values.length < period) return result;
  double sum = 0;
  for (var i = 0; i < values.length; i++) {
    sum += values[i];
    if (i >= period) sum -= values[i - period];
    if (i >= period - 1) result[i] = sum / period;
  }
  return result;
}

/// A rolling mean over a series with a leading run of `null`s: the window
/// opens once [period] values are in.
List<double?> _rollingMeanNullable(List<double?> values, int period) {
  final result = List<double?>.filled(values.length, null);
  final first = values.indexWhere((v) => v != null);
  if (first == -1) return result;
  final dense = _rollingMean([for (final v in values.skip(first)) v!], period);
  for (var k = 0; k < dense.length; k++) {
    result[first + k] = dense[k];
  }
  return result;
}

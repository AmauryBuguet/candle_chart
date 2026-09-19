import 'dart:ui';

import '../models/chart_candle.dart';
import '../models/chart_colors.dart';
import '../models/chart_indicator.dart';
import 'indicator_render.dart';
import 'indicators.dart';

/// Turns an indicator's parameters and the candles into the series the
/// painter draws. The painter knows nothing about indicators; this is the
/// one place that does.
IndicatorRender renderIndicator(ChartIndicator indicator, List<ChartCandle> candles, ChartColors colors) {
  return switch (indicator) {
    ChartSma(:final period, :final color) => IndicatorRender(
      series: [IndicatorSeries(values: simpleMovingAverage(candles, period), color: color)],
    ),
    ChartEma(:final period, :final color) => IndicatorRender(
      series: [IndicatorSeries(values: exponentialMovingAverage(candles, period), color: color)],
    ),
    ChartWma(:final period, :final color) => IndicatorRender(
      series: [IndicatorSeries(values: weightedMovingAverage(candles, period), color: color)],
    ),
    ChartVwap(:final color) => IndicatorRender(
      series: [IndicatorSeries(values: volumeWeightedAveragePrice(candles), color: color)],
    ),
    ChartBollinger(:final period, :final deviation, :final color) => _bollinger(candles, period, deviation, color),
    ChartIchimoku() => _ichimoku(candles, indicator),
    ChartSuperTrend(:final period, :final multiplier, :final upColor, :final downColor) => _superTrend(
      candles,
      period,
      multiplier,
      upColor,
      downColor,
    ),
    ChartVolumeProfile() => const IndicatorRender(),
    ChartVolume() => _volume(candles, colors),
    ChartRsi(:final period, :final color, :final overbought, :final oversold) => IndicatorRender(
      series: [IndicatorSeries(values: relativeStrengthIndex(candles, period), color: color)],
      levels: [oversold, overbought],
      fixedRange: (0, 100),
    ),
    ChartMacd() => _macd(candles, indicator),
    ChartStochastic() => _stochastic(candles, indicator),
  };
}

IndicatorRender _bollinger(List<ChartCandle> candles, int period, double deviation, Color color) {
  final bands = bollingerBands(candles, period, deviation);
  return IndicatorRender(
    series: [
      IndicatorSeries(values: [for (final b in bands) b?.upper], color: color, width: 1),
      IndicatorSeries(values: [for (final b in bands) b?.lower], color: color, width: 1),
      IndicatorSeries(values: [for (final b in bands) b?.middle], color: color, width: 0.6),
    ],
    bands: [IndicatorBand(first: 0, second: 1, above: color.withAlpha(20), below: color.withAlpha(20))],
  );
}

IndicatorRender _ichimoku(List<ChartCandle> candles, ChartIchimoku indicator) {
  final lines = ichimoku(candles, indicator.conversionPeriod, indicator.basePeriod, indicator.spanPeriod);
  return IndicatorRender(
    series: [
      IndicatorSeries(
        values: [for (final l in lines) l?.spanA],
        color: indicator.spanAColor,
        width: 1,
        offset: indicator.displacement,
      ),
      IndicatorSeries(
        values: [for (final l in lines) l?.spanB],
        color: indicator.spanBColor,
        width: 1,
        offset: indicator.displacement,
      ),
      IndicatorSeries(values: [for (final l in lines) l?.conversion], color: indicator.conversionColor),
      IndicatorSeries(values: [for (final l in lines) l?.base], color: indicator.baseColor),
      IndicatorSeries(
        values: [for (final c in candles) c.close],
        color: indicator.laggingColor,
        width: 1,
        offset: -indicator.displacement,
      ),
    ],
    bands: [
      IndicatorBand(
        first: 0,
        second: 1,
        above: indicator.spanAColor.withAlpha(40),
        below: indicator.spanBColor.withAlpha(40),
      ),
    ],
  );
}

IndicatorRender _superTrend(List<ChartCandle> candles, int period, double multiplier, Color upColor, Color downColor) {
  final trend = superTrend(candles, period, multiplier);
  return IndicatorRender(
    series: [
      IndicatorSeries(values: [for (final t in trend) t != null && t.up ? t.value : null], color: upColor),
      IndicatorSeries(values: [for (final t in trend) t != null && !t.up ? t.value : null], color: downColor),
    ],
  );
}

IndicatorRender _volume(List<ChartCandle> candles, ChartColors colors) {
  return IndicatorRender(
    series: [
      IndicatorSeries(
        values: [for (final c in candles) c.volume],
        color: colors.doji,
        kind: SeriesKind.histogram,
        barColors: [
          for (final c in candles)
            (c.close > c.open
                    ? colors.upCandle
                    : c.close < c.open
                    ? colors.downCandle
                    : colors.doji)
                .withAlpha(110),
        ],
      ),
    ],
    fixedRange: null,
  );
}

IndicatorRender _macd(List<ChartCandle> candles, ChartMacd indicator) {
  final values = macd(candles, indicator.fastPeriod, indicator.slowPeriod, indicator.signalPeriod);
  return IndicatorRender(
    series: [
      IndicatorSeries(
        values: [for (final v in values) v?.histogram],
        color: indicator.upColor,
        kind: SeriesKind.histogram,
        barColors: [
          for (final v in values)
            v == null
                ? null
                : v.histogram >= 0
                ? indicator.upColor.withAlpha(140)
                : indicator.downColor.withAlpha(140),
        ],
      ),
      IndicatorSeries(values: [for (final v in values) v?.macd], color: indicator.macdColor),
      IndicatorSeries(values: [for (final v in values) v?.signal], color: indicator.signalColor),
    ],
    levels: const [0],
  );
}

IndicatorRender _stochastic(List<ChartCandle> candles, ChartStochastic indicator) {
  final values = stochastic(candles, indicator.kPeriod, indicator.kSmoothing, indicator.dPeriod);
  return IndicatorRender(
    series: [
      IndicatorSeries(values: [for (final v in values) v?.k], color: indicator.kColor),
      IndicatorSeries(values: [for (final v in values) v?.d], color: indicator.dColor),
    ],
    levels: [indicator.oversold, indicator.overbought],
    fixedRange: (0, 100),
  );
}

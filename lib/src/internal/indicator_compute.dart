import 'dart:ui';

import '../models/chart_candle.dart';
import '../models/chart_colors.dart';
import '../models/chart_indicator.dart';
import 'calendar.dart';
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
    ChartPeriodLevels() => _periodLevels(candles, indicator),
    ChartSessions() => _sessions(candles, indicator),
    ChartVolumeProfile() => const IndicatorRender(),
    ChartVolume() => _volume(candles, colors),
    ChartRsi(:final period, :final color, :final overbought, :final oversold) => IndicatorRender(
      series: [IndicatorSeries(values: relativeStrengthIndex(candles, period), color: color)],
      levels: [oversold, overbought],
      fixedRange: (0, 100),
    ),
    ChartMacd() => _macd(candles, indicator),
    ChartStochastic() => _stochastic(candles, indicator),
    ChartAtr(:final period, :final color) => IndicatorRender(
      series: [IndicatorSeries(values: averageTrueRange(candles, period), color: color)],
    ),
  };
}

IndicatorRender _periodLevels(List<ChartCandle> candles, ChartPeriodLevels indicator) {
  final levels = periodLevels(candles, indicator);
  if (levels == null) return const IndicatorRender();

  IndicatorSeries? level(double? value, Color? color, String label, {double width = 1.2}) {
    if (value == null || color == null) return null;
    return IndicatorSeries(
      values: [for (var i = 0; i < candles.length; i++) i >= levels.from ? value : null],
      color: color,
      width: width,
      kind: SeriesKind.step,
      label: label,
    );
  }

  return IndicatorRender(
    series: [
      ?level(levels.previousHigh, indicator.previousHighColor, indicator.previousHighLabel),
      ?level(levels.previousLow, indicator.previousLowColor, indicator.previousLowLabel),
      ?level(levels.open, indicator.openColor, indicator.openLabel, width: 1),
      ?level(levels.high, indicator.highColor, indicator.highLabel, width: 1),
      ?level(levels.low, indicator.lowColor, indicator.lowLabel, width: 1),
    ],
  );
}

IndicatorRender _sessions(List<ChartCandle> candles, ChartSessions indicator) => IndicatorRender(
  boxes: [
    for (final range in sessionRanges(candles))
      if (_sessionStyle(indicator, range.session) case (final Color color, final String label))
        IndicatorBox(start: range.start, end: range.end, low: range.low, high: range.high, color: color, label: label),
  ],
);

(Color?, String) _sessionStyle(ChartSessions indicator, MarketSession session) => switch (session) {
  MarketSession.asia => (indicator.asiaColor, indicator.asiaLabel),
  MarketSession.london => (indicator.londonColor, indicator.londonLabel),
  MarketSession.newYork => (indicator.newYorkColor, indicator.newYorkLabel),
};

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
  final ChartIchimoku(:spanAColor, :spanBColor, :conversionColor, :baseColor, :laggingColor) = indicator;
  return IndicatorRender(
    series: [
      if (spanAColor != null)
        IndicatorSeries(
          values: [for (final l in lines) l?.spanA],
          color: spanAColor,
          width: 1,
          offset: indicator.displacement,
        ),
      if (spanBColor != null)
        IndicatorSeries(
          values: [for (final l in lines) l?.spanB],
          color: spanBColor,
          width: 1,
          offset: indicator.displacement,
        ),
      if (conversionColor != null)
        IndicatorSeries(values: [for (final l in lines) l?.conversion], color: conversionColor),
      if (baseColor != null) IndicatorSeries(values: [for (final l in lines) l?.base], color: baseColor),
      if (laggingColor != null)
        IndicatorSeries(
          values: [for (final c in candles) c.close],
          color: laggingColor,
          width: 1,
          offset: -indicator.displacement,
        ),
    ],
    bands: [
      if (spanAColor != null && spanBColor != null)
        IndicatorBand(first: 0, second: 1, above: spanAColor.withAlpha(40), below: spanBColor.withAlpha(40)),
    ],
  );
}

IndicatorRender _superTrend(
  List<ChartCandle> candles,
  int period,
  double multiplier,
  Color? upColor,
  Color? downColor,
) {
  final trend = superTrend(candles, period, multiplier);
  return IndicatorRender(
    series: [
      if (upColor != null)
        IndicatorSeries(values: [for (final t in trend) t != null && t.up ? t.value : null], color: upColor),
      if (downColor != null)
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
  final ChartMacd(:upColor, :downColor, :macdColor, :signalColor) = indicator;
  return IndicatorRender(
    series: [
      if (upColor != null || downColor != null)
        IndicatorSeries(
          values: [for (final v in values) v?.histogram],
          color: upColor ?? downColor!,
          kind: SeriesKind.histogram,
          barColors: [
            for (final v in values)
              v == null
                  ? null
                  : v.histogram >= 0
                  ? upColor?.withAlpha(140)
                  : downColor?.withAlpha(140),
          ],
        ),
      if (macdColor != null) IndicatorSeries(values: [for (final v in values) v?.macd], color: macdColor),
      if (signalColor != null) IndicatorSeries(values: [for (final v in values) v?.signal], color: signalColor),
    ],
    levels: const [0],
  );
}

IndicatorRender _stochastic(List<ChartCandle> candles, ChartStochastic indicator) {
  final values = stochastic(candles, indicator.kPeriod, indicator.kSmoothing, indicator.dPeriod);
  final ChartStochastic(:kColor, :dColor) = indicator;
  return IndicatorRender(
    series: [
      if (kColor != null) IndicatorSeries(values: [for (final v in values) v?.k], color: kColor),
      if (dColor != null) IndicatorSeries(values: [for (final v in values) v?.d], color: dColor),
    ],
    levels: [indicator.oversold, indicator.overbought],
    fixedRange: (0, 100),
  );
}

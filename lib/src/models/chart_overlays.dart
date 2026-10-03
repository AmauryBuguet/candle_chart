part of 'chart_indicator.dart';

/// A simple moving average of the closes.
class ChartSma extends ChartOverlay {
  const ChartSma({required this.period, required this.color}) : assert(period > 0);

  final int period;
  final Color color;

  @override
  List<Object> get props => [period, color];
}

/// An exponential moving average of the closes.
class ChartEma extends ChartOverlay {
  const ChartEma({required this.period, required this.color}) : assert(period > 0);

  final int period;
  final Color color;

  @override
  List<Object> get props => [period, color];
}

/// A weighted moving average of the closes, the latest close weighing most.
class ChartWma extends ChartOverlay {
  const ChartWma({required this.period, required this.color}) : assert(period > 0);

  final int period;
  final Color color;

  @override
  List<Object> get props => [period, color];
}

/// The volume-weighted average price since the start of the UTC day, reset
/// at every day boundary.
class ChartVwap extends ChartOverlay {
  const ChartVwap({required this.color});

  final Color color;

  @override
  List<Object> get props => [color];
}

/// Bollinger Bands: a simple moving average of the closes with a band on
/// each side at [deviation] standard deviations.
class ChartBollinger extends ChartOverlay {
  const ChartBollinger({required this.period, required this.deviation, required this.color})
    : assert(period > 1),
      assert(deviation > 0);

  final int period;
  final double deviation;
  final Color color;

  @override
  List<Object> get props => [period, deviation, color];
}

/// Ichimoku Kinko Hyo: conversion and base lines, the cloud between the two
/// leading spans drawn [displacement] candles ahead, and the lagging span
/// drawn as many behind. A line with no colour is not drawn, and the cloud
/// only with both spans.
class ChartIchimoku extends ChartOverlay {
  const ChartIchimoku({
    this.conversionPeriod = 9,
    this.basePeriod = 26,
    this.spanPeriod = 52,
    this.displacement = 26,
    required this.conversionColor,
    required this.baseColor,
    required this.spanAColor,
    required this.spanBColor,
    required this.laggingColor,
  }) : assert(conversionPeriod > 0 && basePeriod > 0 && spanPeriod > 0 && displacement >= 0);

  final int conversionPeriod;
  final int basePeriod;
  final int spanPeriod;
  final int displacement;
  final Color? conversionColor;
  final Color? baseColor;
  final Color? spanAColor;
  final Color? spanBColor;
  final Color? laggingColor;

  @override
  List<Object?> get props => [
    conversionPeriod,
    basePeriod,
    spanPeriod,
    displacement,
    conversionColor,
    baseColor,
    spanAColor,
    spanBColor,
    laggingColor,
  ];
}

/// SuperTrend: an ATR band that trails the price and flips side when the
/// close crosses it, drawn in [upColor] under a rising market and in
/// [downColor] over a falling one; a side with no colour is not drawn.
class ChartSuperTrend extends ChartOverlay {
  const ChartSuperTrend({
    this.period = 10,
    this.multiplier = 3,
    required this.upColor,
    required this.downColor,
  }) : assert(period > 0 && multiplier > 0);

  final int period;
  final double multiplier;
  final Color? upColor;
  final Color? downColor;

  @override
  List<Object?> get props => [period, multiplier, upColor, downColor];
}

/// The visible-range volume profile: the visible candles' volume binned by
/// price and drawn as a histogram against the right edge, the busiest bin
/// (the point of control) in [pocColor].
class ChartVolumeProfile extends ChartOverlay {
  const ChartVolumeProfile({required this.color, required this.pocColor});

  final Color color;
  final Color pocColor;

  @override
  List<Object> get props => [color, pocColor];
}

/// The calendar periods [ChartPeriodLevels] reads its levels from, in UTC:
/// a week starts on Monday.
enum ChartLevelPeriod {
  day(Duration(days: 1)),
  week(Duration(days: 7)),
  month(Duration(days: 28));

  const ChartLevelPeriod(this.shortest);

  /// The shortest such period: candles at least this long show no levels.
  final Duration shortest;

  /// The start of the period holding [timestamp], in UTC milliseconds.
  int startOf(int timestamp) {
    const dayMs = Duration.millisecondsPerDay;
    final day = timestamp - timestamp % dayMs;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
    return switch (this) {
      ChartLevelPeriod.day => day,
      // The epoch fell on a Thursday, three days after a Monday.
      ChartLevelPeriod.week => day - ((day ~/ dayMs + 3) % 7) * dayMs,
      ChartLevelPeriod.month => DateTime.utc(date.year, date.month).millisecondsSinceEpoch,
    };
  }

  /// The start of the period after the one starting at [start].
  int nextStart(int start) => _shifted(start, 1);

  /// The start of the period before the one starting at [start].
  int previousStart(int start) => _shifted(start, -1);

  int _shifted(int start, int by) {
    final date = DateTime.fromMillisecondsSinceEpoch(start, isUtc: true);
    return switch (this) {
      ChartLevelPeriod.day => start + by * Duration.millisecondsPerDay,
      ChartLevelPeriod.week => start + by * 7 * Duration.millisecondsPerDay,
      ChartLevelPeriod.month => DateTime.utc(date.year, date.month + by).millisecondsSinceEpoch,
    };
  }
}

/// A period's open, high and low, as the host knows them: a day, week or
/// month it has from candles of its own, longer than the chart's.
class ChartPeriodRange extends Equatable {
  const ChartPeriodRange({required this.start, required this.open, required this.high, required this.low});

  /// When the period starts, as [ChartLevelPeriod.startOf] has it.
  final int start;
  final double open;
  final double high;
  final double low;

  @override
  List<Object> get props => [start, open, high, low];
}

/// The current [period]'s levels, drawn from its start to the last candle
/// with each label at the right end where it fits: the previous period's
/// high and low, the current one's open, and its high and low so far.
///
/// The host may pass the [previous] and [current] ranges, read from longer
/// candles, since the chart's may not reach back that far; the current one
/// is carried on by the candles since it was read. Without them, a level
/// is read off the candles where they cover its period. Nothing on candles
/// as long as the period; a level with no colour is not drawn.
class ChartPeriodLevels extends ChartOverlay {
  const ChartPeriodLevels({
    required this.period,
    required this.previousHighColor,
    required this.previousLowColor,
    required this.openColor,
    required this.highColor,
    required this.lowColor,
    this.previous,
    this.current,
    this.previousHighLabel = '',
    this.previousLowLabel = '',
    this.openLabel = '',
    this.highLabel = '',
    this.lowLabel = '',
  });

  final ChartLevelPeriod period;
  final ChartPeriodRange? previous;
  final ChartPeriodRange? current;
  final Color? previousHighColor;
  final Color? previousLowColor;
  final Color? openColor;
  final Color? highColor;
  final Color? lowColor;
  final String previousHighLabel;
  final String previousLowLabel;
  final String openLabel;
  final String highLabel;
  final String lowLabel;

  @override
  List<Object?> get props => [
    period,
    previous,
    current,
    previousHighColor,
    previousLowColor,
    openColor,
    highColor,
    lowColor,
    previousHighLabel,
    previousLowLabel,
    openLabel,
    highLabel,
    lowLabel,
  ];
}

/// The Asian, London and New York sessions, each a box from its open to
/// its close spanning its high and low, labelled in its top corner where
/// the label fits, on candles of an hour or less. Forex hours, daylight
/// saving included: Tokyo 9:00 to 18:00, London and New York 8:00 to 17:00,
/// local time, on weekdays. A session with no colour is not drawn.
class ChartSessions extends ChartOverlay {
  const ChartSessions({
    required this.asiaColor,
    required this.londonColor,
    required this.newYorkColor,
    this.asiaLabel = '',
    this.londonLabel = '',
    this.newYorkLabel = '',
  });

  final Color? asiaColor;
  final Color? londonColor;
  final Color? newYorkColor;
  final String asiaLabel;
  final String londonLabel;
  final String newYorkLabel;

  @override
  List<Object?> get props => [asiaColor, londonColor, newYorkColor, asiaLabel, londonLabel, newYorkLabel];
}

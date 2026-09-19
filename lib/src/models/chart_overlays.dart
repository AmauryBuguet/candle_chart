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
/// drawn as many behind.
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
  final Color conversionColor;
  final Color baseColor;
  final Color spanAColor;
  final Color spanBColor;
  final Color laggingColor;

  @override
  List<Object> get props => [
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
/// [downColor] over a falling one.
class ChartSuperTrend extends ChartOverlay {
  const ChartSuperTrend({
    this.period = 10,
    this.multiplier = 3,
    required this.upColor,
    required this.downColor,
  }) : assert(period > 0 && multiplier > 0);

  final int period;
  final double multiplier;
  final Color upColor;
  final Color downColor;

  @override
  List<Object> get props => [period, multiplier, upColor, downColor];
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

part of 'chart_indicator.dart';

/// Each candle's volume as a bar, in its candle's colour.
class ChartVolume extends ChartPaneIndicator {
  const ChartVolume({super.height = 0.15});

  @override
  List<Object> get props => [height];

  @override
  String formatValue(double value) => formatCompact(value);
}

/// The relative strength index of the closes, with guide lines at the
/// [oversold] and [overbought] levels.
class ChartRsi extends ChartPaneIndicator {
  const ChartRsi({
    this.period = 14,
    required this.color,
    this.overbought = 70,
    this.oversold = 30,
    super.height,
  }) : assert(period > 0);

  final int period;
  final Color color;
  final double overbought;
  final double oversold;

  @override
  List<Object> get props => [period, color, overbought, oversold, height];

  @override
  String formatValue(double value) => value.toStringAsFixed(0);
}

/// Moving average convergence/divergence: the difference of two EMAs, its
/// signal EMA, and their gap as a histogram.
class ChartMacd extends ChartPaneIndicator {
  const ChartMacd({
    this.fastPeriod = 12,
    this.slowPeriod = 26,
    this.signalPeriod = 9,
    required this.macdColor,
    required this.signalColor,
    required this.upColor,
    required this.downColor,
    super.height,
  }) : assert(fastPeriod > 0 && slowPeriod > fastPeriod && signalPeriod > 0);

  final int fastPeriod;
  final int slowPeriod;
  final int signalPeriod;
  final Color macdColor;
  final Color signalColor;
  final Color upColor;
  final Color downColor;

  @override
  List<Object> get props => [fastPeriod, slowPeriod, signalPeriod, macdColor, signalColor, upColor, downColor, height];

  @override
  String formatValue(double value) => formatCompact(value);
}

/// The stochastic oscillator: where the close sits in the recent range (%K,
/// smoothed) and its moving average (%D), with guide lines at the
/// [oversold] and [overbought] levels.
class ChartStochastic extends ChartPaneIndicator {
  const ChartStochastic({
    this.kPeriod = 14,
    this.kSmoothing = 3,
    this.dPeriod = 3,
    required this.kColor,
    required this.dColor,
    this.overbought = 80,
    this.oversold = 20,
    super.height,
  }) : assert(kPeriod > 0 && kSmoothing > 0 && dPeriod > 0);

  final int kPeriod;
  final int kSmoothing;
  final int dPeriod;
  final Color kColor;
  final Color dColor;
  final double overbought;
  final double oversold;

  @override
  List<Object> get props => [kPeriod, kSmoothing, dPeriod, kColor, dColor, overbought, oversold, height];

  @override
  String formatValue(double value) => value.toStringAsFixed(0);
}

/// A short reading of a value whose scale is unknown in advance: thousands
/// and millions abbreviated, small values kept to a few significant digits.
String formatCompact(double value) {
  final magnitude = value.abs();
  if (magnitude >= 1e9) return '${(value / 1e9).toStringAsFixed(2)}B';
  if (magnitude >= 1e6) return '${(value / 1e6).toStringAsFixed(2)}M';
  if (magnitude >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
  if (magnitude >= 100) return value.toStringAsFixed(0);
  if (magnitude >= 1) return value.toStringAsFixed(2);
  if (magnitude == 0) return '0';
  return value.toStringAsPrecision(3);
}

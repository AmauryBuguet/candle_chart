import 'package:equatable/equatable.dart';

import 'chart_bollinger.dart';
import 'chart_colors.dart';
import 'chart_ema.dart';
import 'chart_label_style.dart';

/// Everything about how the chart looks: which optional overlays are drawn,
/// and their colors/label styling. Behavior (pan/zoom bounds) is configured
/// separately via `ChartViewConfig`, since it's read by the chart's
/// controller rather than its painter.
class ChartStyle extends Equatable {
  /// Creates a new instance of [ChartStyle].
  const ChartStyle({
    this.crosshair = true,
    this.grid = true,
    this.vpvr = false,
    this.volume = false,
    this.emas = const [],
    this.bollinger,
    this.filledUpCandles = false,
    this.filledDownCandles = false,
    this.colors = const ChartColors(),
    this.labelStyle = const ChartLabelStyle(),
  });

  /// Whether to show the crosshair cursor.
  final bool crosshair;

  /// Whether to show the grid lines.
  final bool grid;

  /// Whether to show the Visible-Range Volume Profile.
  final bool vpvr;

  /// Whether to draw each candle's volume as a bar along the bottom of the
  /// chart.
  final bool volume;

  /// The moving averages drawn over the candles.
  final List<ChartEma> emas;

  /// Bollinger Bands around the candles, none when null.
  final ChartBollinger? bollinger;

  /// Whether an up candle's body is filled rather than left hollow.
  final bool filledUpCandles;

  /// Whether a down candle's body is filled rather than left hollow.
  final bool filledDownCandles;

  /// The color configuration for the chart.
  final ChartColors colors;

  /// Styling for axis and crosshair labels.
  final ChartLabelStyle labelStyle;

  /// Returns a copy of this [ChartStyle] with optional new values.
  ChartStyle copyWith({
    bool? crosshair,
    bool? grid,
    bool? vpvr,
    bool? volume,
    List<ChartEma>? emas,
    ChartBollinger? Function()? bollinger,
    bool? filledUpCandles,
    bool? filledDownCandles,
    ChartColors? colors,
    ChartLabelStyle? labelStyle,
  }) {
    return ChartStyle(
      crosshair: crosshair ?? this.crosshair,
      grid: grid ?? this.grid,
      vpvr: vpvr ?? this.vpvr,
      volume: volume ?? this.volume,
      emas: emas ?? this.emas,
      bollinger: bollinger == null ? this.bollinger : bollinger(),
      filledUpCandles: filledUpCandles ?? this.filledUpCandles,
      filledDownCandles: filledDownCandles ?? this.filledDownCandles,
      colors: colors ?? this.colors,
      labelStyle: labelStyle ?? this.labelStyle,
    );
  }

  @override
  List<Object?> get props => [
    crosshair,
    grid,
    colors,
    labelStyle,
    vpvr,
    volume,
    emas,
    bollinger,
    filledUpCandles,
    filledDownCandles,
  ];
}

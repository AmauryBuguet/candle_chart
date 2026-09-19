import 'package:equatable/equatable.dart';

import 'chart_colors.dart';
import 'chart_label_style.dart';

/// Everything about how the chart looks: the crosshair and grid, the candle
/// bodies, colours and label styling. What is drawn from the candles is the
/// chart's `indicators`; behaviour (pan/zoom bounds) is `ChartViewConfig`,
/// read by the controller rather than the painter.
class ChartStyle extends Equatable {
  /// Creates a new instance of [ChartStyle].
  const ChartStyle({
    this.crosshair = true,
    this.grid = true,
    this.filledUpCandles = false,
    this.filledDownCandles = false,
    this.colors = const ChartColors(),
    this.labelStyle = const ChartLabelStyle(),
  });

  /// Whether to show the crosshair cursor.
  final bool crosshair;

  /// Whether to show the grid lines.
  final bool grid;

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
    bool? filledUpCandles,
    bool? filledDownCandles,
    ChartColors? colors,
    ChartLabelStyle? labelStyle,
  }) {
    return ChartStyle(
      crosshair: crosshair ?? this.crosshair,
      grid: grid ?? this.grid,
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
    filledUpCandles,
    filledDownCandles,
  ];
}

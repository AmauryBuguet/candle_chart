import 'package:equatable/equatable.dart';

import 'chart_colors.dart';
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
    this.colors = const ChartColors(),
    this.labelStyle = const ChartLabelStyle(),
  });

  /// Whether to show the crosshair cursor.
  final bool crosshair;

  /// Whether to show the grid lines.
  final bool grid;

  /// Whether to show the Visible-Range Volume Profile.
  final bool vpvr;

  /// The color configuration for the chart.
  final ChartColors colors;

  /// Styling for axis and crosshair labels.
  final ChartLabelStyle labelStyle;

  /// Returns a copy of this [ChartStyle] with optional new values.
  ChartStyle copyWith({
    bool? crosshair,
    bool? grid,
    bool? vpvr,
    ChartColors? colors,
    ChartLabelStyle? labelStyle,
  }) {
    return ChartStyle(
      crosshair: crosshair ?? this.crosshair,
      grid: grid ?? this.grid,
      vpvr: vpvr ?? this.vpvr,
      colors: colors ?? this.colors,
      labelStyle: labelStyle ?? this.labelStyle,
    );
  }

  @override
  List<Object> get props => [crosshair, grid, colors, labelStyle, vpvr];
}

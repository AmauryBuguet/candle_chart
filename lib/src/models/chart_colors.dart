import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'chart_drawing.dart';

/// Defines the color scheme used in the chart. All fields default to a
/// neutral palette; hosts should normally supply their own theme colors.
class ChartColors extends Equatable {
  /// Creates a new instance of [ChartColors].
  const ChartColors({
    this.background = Colors.transparent,
    this.upCandle = Colors.white70,
    this.downCandle = Colors.redAccent,
    this.doji = Colors.blueAccent,
    this.crosshair = Colors.white70,
    this.crosshairLabelBackground = Colors.blueGrey,
    this.crosshairLabelText = Colors.white,
    this.cursor = Colors.white,
    this.grid = Colors.white70,
    this.positionProfit = Colors.green,
    this.positionLoss = Colors.red,
    this.line = Colors.white70,
    this.drawing = Colors.blueAccent,
    this.fibLevels = const [],
  });

  /// Background color of the chart.
  final Color background;

  /// Color of an up (bullish) candlestick.
  final Color upCandle;

  /// Color of a down (bearish) candlestick.
  final Color downCandle;

  /// Color of a doji candlestick.
  final Color doji;

  /// Color of the crosshair lines, if enabled.
  final Color crosshair;

  /// Background color of the crosshair's time/price labels.
  final Color crosshairLabelBackground;

  /// Text color of the crosshair's time/price labels.
  final Color crosshairLabelText;

  /// Color of the crosshair with a tool in hand — the cursor it is aimed
  /// with on a phone — drawn thicker than the idle crosshair so the two tell
  /// apart.
  final Color cursor;

  /// Color of the grid lines.
  final Color grid;

  /// Color used for the winning-side position overlay.
  final Color positionProfit;

  /// Color used for the losing-side position overlay.
  final Color positionLoss;

  /// The price line when the chart type is `ChartType.line`.
  final Color line;

  /// The colour a drawing is created in.
  final Color drawing;

  /// The colour a new Fibonacci drawing's level of each ratio is created
  /// in, the same in a retracement and an extension; a level whose ratio is
  /// not here takes the drawing's.
  final List<ChartFibLevel> fibLevels;

  @override
  List<Object> get props => [
    fibLevels,
    background,
    upCandle,
    downCandle,
    doji,
    crosshair,
    crosshairLabelBackground,
    crosshairLabelText,
    cursor,
    grid,
    positionProfit,
    positionLoss,
    line,
    drawing,
  ];
}

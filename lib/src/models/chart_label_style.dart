import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Styling and spacing shared by every text label the chart draws: axis
/// ticks and the crosshair's time/price labels.
class ChartLabelStyle extends Equatable {
  /// Creates an immutable [ChartLabelStyle] instance.
  const ChartLabelStyle({
    this.padding = 3.0,
    this.labelMargin = 7.0,
    this.minSpacingPxTimeAxis = 80,
    this.minSpacingPxPriceAxis = 50,
    this.textStyle = const TextStyle(color: Colors.grey),
    this.locale = 'en_US',
  });

  /// Padding inside the rectangles around crosshair labels.
  final double padding;

  /// Space between labels and the axis.
  final double labelMargin;

  /// Minimum pixel spacing for the time axis.
  final double minSpacingPxTimeAxis;

  /// Minimum pixel spacing for the price axis.
  final double minSpacingPxPriceAxis;

  /// Text style of axis and crosshair labels.
  final TextStyle textStyle;

  /// Locale used to format time labels.
  final String locale;

  @override
  List<Object> get props => [
    padding,
    labelMargin,
    minSpacingPxTimeAxis,
    minSpacingPxPriceAxis,
    textStyle,
    locale,
  ];
}

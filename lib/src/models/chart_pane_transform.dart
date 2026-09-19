import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'axis.dart';

/// One indicator pane's rectangle and value axis, in the chart widget's
/// coordinate space, so a host can place its own chrome on the pane.
class ChartPaneTransform extends Equatable {
  const ChartPaneTransform({required this.rect, required this.axis});

  /// The pane's plotted area, gutters excluded.
  final Rect rect;

  /// The value range the pane shows, bottom to top.
  final PriceAxis axis;

  double yForValue(double value) => rect.top + (1 - (value - axis.start) / axis.range) * rect.height;

  double valueForY(double y) => axis.start + (rect.bottom - y) / rect.height * axis.range;

  @override
  List<Object> get props => [rect, axis];
}

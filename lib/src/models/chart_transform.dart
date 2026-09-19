import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'axis.dart';
import 'chart_margins.dart';
import 'chart_pane_transform.dart';

/// The chart's price/time to pixel mapping, in the chart widget's own
/// coordinate space.
///
/// Published by the chart so a host can draw its own layer on top of it
/// (order lines, labels, handles) without duplicating the axis maths.
class ChartTransform extends Equatable {
  const ChartTransform({
    required this.size,
    required this.margins,
    required this.priceAxis,
    required this.timeAxis,
    this.paneSpace = 0,
    this.panes = const [],
  });

  /// Size of the chart widget, axis gutters included.
  final Size size;
  final ChartMargins margins;
  final PriceAxis priceAxis;
  final TimeAxis timeAxis;

  /// The height the indicator panes and their handles take under the price
  /// pane, above the time axis gutter.
  final double paneSpace;

  /// The indicator panes, top to bottom.
  final List<ChartPaneTransform> panes;

  /// The price pane, i.e. [size] minus the axis gutters and [paneSpace].
  Rect get plotArea => Rect.fromLTRB(
    margins.left,
    margins.top,
    size.width - margins.right,
    size.height - margins.bottom - paneSpace,
  );

  double yForPrice(double price) =>
      plotArea.top + (1 - (price - priceAxis.start) / priceAxis.range) * plotArea.height;

  double priceForY(double y) =>
      priceAxis.start + (plotArea.bottom - y) / plotArea.height * priceAxis.range;

  double xForTime(int timestamp) =>
      plotArea.left + (timestamp - timeAxis.start) / timeAxis.range * plotArea.width;

  int timeForX(double x) =>
      timeAxis.start + ((x - plotArea.left) / plotArea.width * timeAxis.range).round();

  /// Whether [price] falls inside the visible price range.
  bool containsPrice(double price) => price >= priceAxis.start && price <= priceAxis.end;

  @override
  List<Object> get props => [size, margins, priceAxis, timeAxis, paneSpace, panes];
}

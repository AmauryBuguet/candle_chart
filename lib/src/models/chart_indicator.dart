import 'dart:ui';

import 'package:equatable/equatable.dart';

part 'chart_overlays.dart';
part 'chart_pane_indicators.dart';

/// A study drawn from the candles: either over them, in price units, or in a
/// pane of its own under the price pane, on its own value axis.
///
/// An indicator is a value object — parameters and colours — and nothing
/// else. The chart computes its series once per candle list and caches them
/// against the instance, so a host keeps its indicators in a list and edits
/// them by replacing an entry.
sealed class ChartIndicator extends Equatable {
  const ChartIndicator();
}

/// An indicator drawn over the candles, sharing the price axis.
sealed class ChartOverlay extends ChartIndicator {
  const ChartOverlay();
}

/// An indicator drawn in a pane of its own under the price pane, with a
/// value axis fitted to what is visible (or fixed, for a bounded oscillator).
sealed class ChartPaneIndicator extends ChartIndicator {
  const ChartPaneIndicator({this.height = 0.2}) : assert(height > 0 && height < 1);

  /// The pane's share of the chart's plot height when it is first shown.
  final double height;

  /// How this pane's axis values read.
  String formatValue(double value);
}

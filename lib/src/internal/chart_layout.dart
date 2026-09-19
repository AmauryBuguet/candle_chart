import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import '../models/chart_margins.dart';

/// The strip between two panes: a hairline to look at and a band to grab.
const double paneHandleHeight = 6;

/// Where the price pane and each indicator pane sit, for one widget size
/// and one set of pane heights.
class ChartLayout extends Equatable {
  ChartLayout({required Size size, required ChartMargins margins, required List<double> paneFractions}) {
    final left = margins.left;
    final right = size.width - margins.right;
    final plotTop = margins.top;
    final plotBottom = size.height - margins.bottom;
    final plotHeight = plotBottom - plotTop;

    var bottom = plotBottom;
    final panes = <Rect>[];
    final handles = <Rect>[];
    for (final fraction in paneFractions.reversed) {
      final height = fraction * plotHeight;
      panes.insert(0, Rect.fromLTRB(left, bottom - height, right, bottom));
      bottom -= height;
      handles.insert(0, Rect.fromLTRB(left, bottom - paneHandleHeight, right, bottom));
      bottom -= paneHandleHeight;
    }
    priceRect = Rect.fromLTRB(left, plotTop, right, bottom);
    paneRects = panes;
    handleRects = handles;
    this.plotTop = plotTop;
    this.plotBottom = plotBottom;
    this.plotHeight = plotHeight;
  }

  late final Rect priceRect;
  late final List<Rect> paneRects;

  /// The grab band above each pane, the same index as [paneRects].
  late final List<Rect> handleRects;
  late final double plotTop;
  late final double plotBottom;
  late final double plotHeight;

  /// What the panes and their handles take under the price pane.
  double get paneSpace => plotBottom - priceRect.bottom;

  /// The price pane and every pane below it, handles included.
  Rect get plotRect => Rect.fromLTRB(priceRect.left, plotTop, priceRect.right, plotBottom);

  @override
  List<Object> get props => [priceRect, paneRects, handleRects];

  /// The index of the pane whose handle is under [position], if any.
  int? handleAt(Offset position) {
    for (var i = 0; i < handleRects.length; i++) {
      if (handleRects[i].inflate(2).contains(position)) return i;
    }
    return null;
  }

  /// The index of the pane under [position], if any.
  int? paneAt(Offset position) {
    for (var i = 0; i < paneRects.length; i++) {
      if (paneRects[i].contains(position)) return i;
    }
    return null;
  }
}

/// Keeps every pane between a sliver and most of the chart, and the price
/// pane at least a fifth of it, whatever a drag asks for.
List<double> clampPaneFractions(List<double> fractions) {
  const minPane = 0.05;
  const maxPane = 0.6;
  const minPrice = 0.2;
  final clamped = [for (final f in fractions) f.clamp(minPane, maxPane)];
  final total = clamped.fold(0.0, (sum, f) => sum + f);
  if (total <= 1 - minPrice) return clamped;
  final scale = (1 - minPrice) / total;
  return [for (final f in clamped) f * scale];
}

import 'dart:ui';

/// How a series is drawn: a polyline through its values, or one bar per
/// value from the pane's zero line.
enum SeriesKind { line, histogram }

/// One series of an indicator, indexed by candle, ready to draw.
class IndicatorSeries {
  const IndicatorSeries({
    required this.values,
    required this.color,
    this.width = 1.2,
    this.kind = SeriesKind.line,
    this.offset = 0,
    this.barColors,
  });

  /// One value per candle, `null` where the series has none yet.
  final List<double?> values;
  final Color color;
  final double width;
  final SeriesKind kind;

  /// How many candles to the right the series is drawn from the candle it
  /// is indexed on; negative draws it to the left.
  final int offset;

  /// A histogram's colour per bar when it is not [color] throughout.
  final List<Color?>? barColors;
}

/// A fill between two series of the same indicator, [above] where the
/// first is over the second and [below] where it is under.
class IndicatorBand {
  const IndicatorBand({required this.first, required this.second, required this.above, required this.below});

  final int first;
  final int second;
  final Color above;
  final Color below;
}

/// Everything the painter needs to draw one indicator: its series, the
/// fills between them, the guide levels of a pane, and the pane's value
/// range when it is fixed rather than fitted to what is visible.
class IndicatorRender {
  const IndicatorRender({
    this.series = const [],
    this.bands = const [],
    this.levels = const [],
    this.fixedRange,
  });

  final List<IndicatorSeries> series;
  final List<IndicatorBand> bands;
  final List<double> levels;
  final (double, double)? fixedRange;
}

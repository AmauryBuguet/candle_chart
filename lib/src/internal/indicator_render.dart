import 'dart:ui';

/// How a series is drawn: a polyline through its values, one bar per value
/// from the pane's zero line, or a level across each candle, joined while
/// it holds and broken where it moves.
enum SeriesKind { line, histogram, step }

/// One series of an indicator, indexed by candle, ready to draw.
class IndicatorSeries {
  const IndicatorSeries({
    required this.values,
    required this.color,
    this.width = 1.2,
    this.kind = SeriesKind.line,
    this.offset = 0,
    this.barColors,
    this.label = '',
  });

  /// One value per candle, `null` where the series has none yet.
  final List<double?> values;
  final Color color;
  final double width;
  final SeriesKind kind;

  /// How many candles to the right the series is drawn from the candle it
  /// is indexed on; negative draws it to the left.
  final int offset;

  /// A histogram's colour per bar when it is not [color] throughout; a bar
  /// with none is not drawn.
  final List<Color?>? barColors;

  /// Written at the right end of each run of a step series, where it fits.
  final String label;
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

/// A box from one time to another spanning two values, filled and outlined
/// in [color], [label] in its top corner where it fits.
class IndicatorBox {
  const IndicatorBox({
    required this.start,
    required this.end,
    required this.low,
    required this.high,
    required this.color,
    this.label = '',
  });

  final int start;
  final int end;
  final double low;
  final double high;
  final Color color;
  final String label;
}

/// Everything the painter needs to draw one indicator: its series, the
/// fills between them, its boxes, the guide levels of a pane, and the
/// pane's value range when it is fixed rather than fitted to what is
/// visible.
class IndicatorRender {
  const IndicatorRender({
    this.series = const [],
    this.bands = const [],
    this.boxes = const [],
    this.levels = const [],
    this.fixedRange,
  });

  final List<IndicatorSeries> series;
  final List<IndicatorBand> bands;
  final List<IndicatorBox> boxes;
  final List<double> levels;
  final (double, double)? fixedRange;
}

part of 'chart_drawing.dart';

/// A segment between two points.
class ChartTrendLine extends ChartDrawing {
  const ChartTrendLine({
    required super.id,
    required super.points,
    required super.color,
    super.width,
    super.lineStyle,
    super.selected,
    super.locked,
    super.hidden,
  });

  @override
  ChartDrawingTool get tool => ChartDrawingTool.trendLine;

  @override
  ChartTrendLine copyWith({
    List<Coordinates>? points,
    Color? color,
    double? width,
    ChartLineStyle? lineStyle,
    bool? selected,
    bool? locked,
    bool? hidden,
  }) => ChartTrendLine(
    id: id,
    points: points ?? this.points,
    color: color ?? this.color,
    width: width ?? this.width,
    lineStyle: lineStyle ?? this.lineStyle,
    selected: selected ?? this.selected,
    locked: locked ?? this.locked,
    hidden: hidden ?? this.hidden,
  );
}

/// A line from the first point through the second and on to the edge.
class ChartRay extends ChartDrawing {
  const ChartRay({
    required super.id,
    required super.points,
    required super.color,
    super.width,
    super.lineStyle,
    super.selected,
    super.locked,
    super.hidden,
  });

  @override
  ChartDrawingTool get tool => ChartDrawingTool.ray;

  @override
  ChartRay copyWith({
    List<Coordinates>? points,
    Color? color,
    double? width,
    ChartLineStyle? lineStyle,
    bool? selected,
    bool? locked,
    bool? hidden,
  }) => ChartRay(
    id: id,
    points: points ?? this.points,
    color: color ?? this.color,
    width: width ?? this.width,
    lineStyle: lineStyle ?? this.lineStyle,
    selected: selected ?? this.selected,
    locked: locked ?? this.locked,
    hidden: hidden ?? this.hidden,
  );
}

/// A line through two points, extended to both edges.
class ChartExtendedLine extends ChartDrawing {
  const ChartExtendedLine({
    required super.id,
    required super.points,
    required super.color,
    super.width,
    super.lineStyle,
    super.selected,
    super.locked,
    super.hidden,
  });

  @override
  ChartDrawingTool get tool => ChartDrawingTool.extendedLine;

  @override
  ChartExtendedLine copyWith({
    List<Coordinates>? points,
    Color? color,
    double? width,
    ChartLineStyle? lineStyle,
    bool? selected,
    bool? locked,
    bool? hidden,
  }) => ChartExtendedLine(
    id: id,
    points: points ?? this.points,
    color: color ?? this.color,
    width: width ?? this.width,
    lineStyle: lineStyle ?? this.lineStyle,
    selected: selected ?? this.selected,
    locked: locked ?? this.locked,
    hidden: hidden ?? this.hidden,
  );
}

/// A line across the chart at the point's price.
class ChartHorizontalLine extends ChartDrawing {
  const ChartHorizontalLine({
    required super.id,
    required super.points,
    required super.color,
    super.width,
    super.lineStyle,
    super.selected,
    super.locked,
    super.hidden,
  });

  @override
  ChartDrawingTool get tool => ChartDrawingTool.horizontalLine;

  @override
  ChartHorizontalLine copyWith({
    List<Coordinates>? points,
    Color? color,
    double? width,
    ChartLineStyle? lineStyle,
    bool? selected,
    bool? locked,
    bool? hidden,
  }) => ChartHorizontalLine(
    id: id,
    points: points ?? this.points,
    color: color ?? this.color,
    width: width ?? this.width,
    lineStyle: lineStyle ?? this.lineStyle,
    selected: selected ?? this.selected,
    locked: locked ?? this.locked,
    hidden: hidden ?? this.hidden,
  );
}

/// A line from the point's time to the right edge at its price.
class ChartHorizontalRay extends ChartDrawing {
  const ChartHorizontalRay({
    required super.id,
    required super.points,
    required super.color,
    super.width,
    super.lineStyle,
    super.selected,
    super.locked,
    super.hidden,
  });

  @override
  ChartDrawingTool get tool => ChartDrawingTool.horizontalRay;

  @override
  ChartHorizontalRay copyWith({
    List<Coordinates>? points,
    Color? color,
    double? width,
    ChartLineStyle? lineStyle,
    bool? selected,
    bool? locked,
    bool? hidden,
  }) => ChartHorizontalRay(
    id: id,
    points: points ?? this.points,
    color: color ?? this.color,
    width: width ?? this.width,
    lineStyle: lineStyle ?? this.lineStyle,
    selected: selected ?? this.selected,
    locked: locked ?? this.locked,
    hidden: hidden ?? this.hidden,
  );
}

/// A line down the chart at the point's time.
class ChartVerticalLine extends ChartDrawing {
  const ChartVerticalLine({
    required super.id,
    required super.points,
    required super.color,
    super.width,
    super.lineStyle,
    super.selected,
    super.locked,
    super.hidden,
  });

  @override
  ChartDrawingTool get tool => ChartDrawingTool.verticalLine;

  @override
  ChartVerticalLine copyWith({
    List<Coordinates>? points,
    Color? color,
    double? width,
    ChartLineStyle? lineStyle,
    bool? selected,
    bool? locked,
    bool? hidden,
  }) => ChartVerticalLine(
    id: id,
    points: points ?? this.points,
    color: color ?? this.color,
    width: width ?? this.width,
    lineStyle: lineStyle ?? this.lineStyle,
    selected: selected ?? this.selected,
    locked: locked ?? this.locked,
    hidden: hidden ?? this.hidden,
  );
}

/// A faintly filled box with two points as opposite corners.
class ChartRectangle extends ChartDrawing {
  const ChartRectangle({
    required super.id,
    required super.points,
    required super.color,
    super.width,
    super.lineStyle,
    super.selected,
    super.locked,
    super.hidden,
  });

  @override
  ChartDrawingTool get tool => ChartDrawingTool.rectangle;

  @override
  ChartRectangle copyWith({
    List<Coordinates>? points,
    Color? color,
    double? width,
    ChartLineStyle? lineStyle,
    bool? selected,
    bool? locked,
    bool? hidden,
  }) => ChartRectangle(
    id: id,
    points: points ?? this.points,
    color: color ?? this.color,
    width: width ?? this.width,
    lineStyle: lineStyle ?? this.lineStyle,
    selected: selected ?? this.selected,
    locked: locked ?? this.locked,
    hidden: hidden ?? this.hidden,
  );
}

/// Two parallel lines: one through the first two points, the other through the third, the band between them faintly filled.
class ChartParallelChannel extends ChartDrawing {
  const ChartParallelChannel({
    required super.id,
    required super.points,
    required super.color,
    super.width,
    super.lineStyle,
    super.selected,
    super.locked,
    super.hidden,
  });

  @override
  ChartDrawingTool get tool => ChartDrawingTool.parallelChannel;

  @override
  ChartParallelChannel copyWith({
    List<Coordinates>? points,
    Color? color,
    double? width,
    ChartLineStyle? lineStyle,
    bool? selected,
    bool? locked,
    bool? hidden,
  }) => ChartParallelChannel(
    id: id,
    points: points ?? this.points,
    color: color ?? this.color,
    width: width ?? this.width,
    lineStyle: lineStyle ?? this.lineStyle,
    selected: selected ?? this.selected,
    locked: locked ?? this.locked,
    hidden: hidden ?? this.hidden,
  );
}

/// Fibonacci retracement levels between the two points' prices, each labelled with its ratio and price.
class ChartFibRetracement extends ChartDrawing {
  const ChartFibRetracement({
    required super.id,
    required super.points,
    required super.color,
    super.width,
    super.lineStyle,
    super.selected,
    super.locked,
    super.hidden,
    this.levels = defaultLevels,
  });

  /// The ratios a new one shows: 1 on the first point's price, 0 on the
  /// second's.
  static const defaultLevels = [
    ChartFibLevel(0),
    ChartFibLevel(0.236),
    ChartFibLevel(0.382),
    ChartFibLevel(0.5),
    ChartFibLevel(0.618),
    ChartFibLevel(0.786),
    ChartFibLevel(1),
  ];

  /// Its levels, each shown or not and in its own colour or the drawing's.
  final List<ChartFibLevel> levels;

  @override
  ChartDrawingTool get tool => ChartDrawingTool.fibRetracement;

  @override
  ChartFibRetracement copyWith({
    List<Coordinates>? points,
    Color? color,
    double? width,
    ChartLineStyle? lineStyle,
    bool? selected,
    bool? locked,
    bool? hidden,
    List<ChartFibLevel>? levels,
  }) => ChartFibRetracement(
    id: id,
    points: points ?? this.points,
    color: color ?? this.color,
    width: width ?? this.width,
    lineStyle: lineStyle ?? this.lineStyle,
    selected: selected ?? this.selected,
    locked: locked ?? this.locked,
    hidden: hidden ?? this.hidden,
    levels: levels ?? this.levels,
  );

  @override
  List<Object?> get props => [...super.props, levels];
}

/// Trend-based Fibonacci extension: the move from the first point to the
/// second, projected from the third, each level labelled with its ratio and
/// price.
class ChartFibExtension extends ChartDrawing {
  const ChartFibExtension({
    required super.id,
    required super.points,
    required super.color,
    super.width,
    super.lineStyle,
    super.selected,
    super.locked,
    super.hidden,
    this.levels = defaultLevels,
  });

  /// The ratios a new one shows: 0 on the third point's price, 1 a whole
  /// first-to-second move away from it.
  static const defaultLevels = [
    ChartFibLevel(0),
    ChartFibLevel(1),
    ChartFibLevel(1.618),
    ChartFibLevel(2.618),
    ChartFibLevel(3.618),
    ChartFibLevel(4.236),
  ];

  /// Its levels, each shown or not and in its own colour or the drawing's.
  final List<ChartFibLevel> levels;

  @override
  ChartDrawingTool get tool => ChartDrawingTool.fibExtension;

  @override
  ChartFibExtension copyWith({
    List<Coordinates>? points,
    Color? color,
    double? width,
    ChartLineStyle? lineStyle,
    bool? selected,
    bool? locked,
    bool? hidden,
    List<ChartFibLevel>? levels,
  }) => ChartFibExtension(
    id: id,
    points: points ?? this.points,
    color: color ?? this.color,
    width: width ?? this.width,
    lineStyle: lineStyle ?? this.lineStyle,
    selected: selected ?? this.selected,
    locked: locked ?? this.locked,
    hidden: hidden ?? this.hidden,
    levels: levels ?? this.levels,
  );

  @override
  List<Object?> get props => [...super.props, levels];
}

/// A box between two points labelled with the change in price and percent, the bars and the time it spans.
class ChartMeasure extends ChartDrawing {
  const ChartMeasure({
    required super.id,
    required super.points,
    required super.color,
    super.width,
    super.lineStyle,
    super.selected,
    super.locked,
    super.hidden,
  });

  @override
  ChartDrawingTool get tool => ChartDrawingTool.measure;

  @override
  ChartMeasure copyWith({
    List<Coordinates>? points,
    Color? color,
    double? width,
    ChartLineStyle? lineStyle,
    bool? selected,
    bool? locked,
    bool? hidden,
  }) => ChartMeasure(
    id: id,
    points: points ?? this.points,
    color: color ?? this.color,
    width: width ?? this.width,
    lineStyle: lineStyle ?? this.lineStyle,
    selected: selected ?? this.selected,
    locked: locked ?? this.locked,
    hidden: hidden ?? this.hidden,
  );
}

/// A note at a point. Created empty by the text tool: editing the text is
/// the host's, through [copyWith].
class ChartText extends ChartDrawing {
  const ChartText({
    required super.id,
    required super.points,
    required super.color,
    required this.text,
    super.width,
    super.lineStyle,
    super.selected,
    super.locked,
    super.hidden,
  });

  final String text;

  @override
  ChartDrawingTool get tool => ChartDrawingTool.text;

  @override
  ChartText copyWith({
    List<Coordinates>? points,
    Color? color,
    double? width,
    ChartLineStyle? lineStyle,
    bool? selected,
    bool? locked,
    bool? hidden,
    String? text,
  }) => ChartText(
    id: id,
    points: points ?? this.points,
    color: color ?? this.color,
    text: text ?? this.text,
    width: width ?? this.width,
    lineStyle: lineStyle ?? this.lineStyle,
    selected: selected ?? this.selected,
    locked: locked ?? this.locked,
    hidden: hidden ?? this.hidden,
  );

  @override
  List<Object?> get props => [...super.props, text];
}

/// Segments joining its points one after the other, as many as were placed.
class ChartPolyline extends ChartDrawing {
  const ChartPolyline({
    required super.id,
    required super.points,
    required super.color,
    super.width,
    super.lineStyle,
    super.selected,
    super.locked,
    super.hidden,
  });

  @override
  ChartDrawingTool get tool => ChartDrawingTool.polyline;

  @override
  ChartPolyline copyWith({
    List<Coordinates>? points,
    Color? color,
    double? width,
    ChartLineStyle? lineStyle,
    bool? selected,
    bool? locked,
    bool? hidden,
  }) => ChartPolyline(
    id: id,
    points: points ?? this.points,
    color: color ?? this.color,
    width: width ?? this.width,
    lineStyle: lineStyle ?? this.lineStyle,
    selected: selected ?? this.selected,
    locked: locked ?? this.locked,
    hidden: hidden ?? this.hidden,
  );
}

import 'dart:ui';

import 'package:equatable/equatable.dart';

import 'coordinates.dart';

part 'chart_drawing_kinds.dart';

/// How a drawing's lines are stroked.
enum ChartLineStyle { solid, dashed, dotted }

/// Something the user drew on the chart, anchored on one to three points in
/// time and price so it moves with the candles.
///
/// A drawing is a value object the host keeps in a list and hands to the
/// chart, exactly like a line: the chart hit-tests, selects and drags it,
/// and reports every change back through callbacks with a new instance.
/// [toJson] and [ChartDrawing.fromJson] carry it to wherever the host keeps
/// it; nothing here is stored.
sealed class ChartDrawing extends Equatable {
  const ChartDrawing({
    required this.id,
    required this.points,
    required this.color,
    this.width = 1,
    this.lineStyle = ChartLineStyle.solid,
    this.selected = false,
    this.locked = false,
    this.hidden = false,
  });

  /// Identifies the drawing to the host; echoed back in every callback.
  final Object id;

  /// The anchors, as many as [tool] needs.
  final List<Coordinates> points;
  final Color color;
  final double width;
  final ChartLineStyle lineStyle;

  /// Shown with its handles; only one drawing should be at a time.
  final bool selected;

  /// A locked drawing can be selected but not moved.
  final bool locked;

  /// A hidden drawing is kept but not drawn nor hit.
  final bool hidden;

  /// Which tool makes this kind of drawing, and how many points it takes.
  ChartDrawingTool get tool;

  ChartDrawing copyWith({
    List<Coordinates>? points,
    Color? color,
    double? width,
    ChartLineStyle? lineStyle,
    bool? selected,
    bool? locked,
    bool? hidden,
  });

  Map<String, dynamic> toJson() => {
    'kind': tool.name,
    'id': id.toString(),
    'points': [
      for (final p in points) {'t': p.timestamp, 'p': p.price},
    ],
    'color': color.toARGB32(),
    'width': width,
    'lineStyle': lineStyle.name,
    'locked': locked,
    'hidden': hidden,
    if (this case ChartText(:final text)) 'text': text,
  };

  /// The drawing [toJson] wrote. The id comes back as the string it was
  /// written as.
  static ChartDrawing fromJson(Map<String, dynamic> json) {
    final tool = ChartDrawingTool.values.byName(json['kind'] as String);
    final points = [
      for (final p in json['points'] as List)
        Coordinates(timestamp: (p as Map)['t'] as int, price: (p['p'] as num).toDouble()),
    ];
    final drawing = tool.create(
      id: json['id'] as String,
      points: points,
      color: Color(json['color'] as int),
      text: json['text'] as String? ?? '',
    );
    return drawing.copyWith(
      width: (json['width'] as num).toDouble(),
      lineStyle: ChartLineStyle.values.byName(json['lineStyle'] as String),
      locked: json['locked'] as bool,
      hidden: json['hidden'] as bool,
    );
  }

  @override
  List<Object?> get props => [id, points, color, width, lineStyle, selected, locked, hidden];
}

/// The drawing tools, each the kind of drawing it makes and how many
/// points it takes to place.
enum ChartDrawingTool {
  trendLine(2),
  ray(2),
  extendedLine(2),
  horizontalLine(1),
  horizontalRay(1),
  verticalLine(1),
  rectangle(2),
  parallelChannel(3),
  fibRetracement(2),
  fibExtension(3),
  text(1),
  measure(2);

  const ChartDrawingTool(this.pointCount);

  final int pointCount;

  ChartDrawing create({required Object id, required List<Coordinates> points, required Color color, String text = ''}) {
    assert(points.length == pointCount);
    return switch (this) {
      trendLine => ChartTrendLine(id: id, points: points, color: color),
      ray => ChartRay(id: id, points: points, color: color),
      extendedLine => ChartExtendedLine(id: id, points: points, color: color),
      horizontalLine => ChartHorizontalLine(id: id, points: points, color: color),
      horizontalRay => ChartHorizontalRay(id: id, points: points, color: color),
      verticalLine => ChartVerticalLine(id: id, points: points, color: color),
      rectangle => ChartRectangle(id: id, points: points, color: color),
      parallelChannel => ChartParallelChannel(id: id, points: points, color: color),
      fibRetracement => ChartFibRetracement(id: id, points: points, color: color),
      fibExtension => ChartFibExtension(id: id, points: points, color: color),
      ChartDrawingTool.text => ChartText(id: id, points: points, color: color, text: text),
      measure => ChartMeasure(id: id, points: points, color: color),
    };
  }
}

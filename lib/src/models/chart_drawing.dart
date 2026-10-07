import 'dart:ui';

import 'package:equatable/equatable.dart';

import 'coordinates.dart';

part 'chart_drawing_kinds.dart';

/// How a drawing's lines are stroked.
enum ChartLineStyle { solid, dashed, dotted }

/// Something the user drew on the chart, anchored on points in time and
/// price so it moves with the candles.
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
    this.hiddenIn = const {},
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

  /// The host's views it is kept out of — timeframes, say: in the one
  /// `TradingChart.view` names it is neither drawn nor hit.
  final Set<String> hiddenIn;

  /// Which tool makes this kind of drawing, and how many points it takes.
  ChartDrawingTool get tool;

  ChartDrawing copyWith({
    List<Coordinates>? points,
    Color? color,
    double? width,
    ChartLineStyle? lineStyle,
    bool? selected,
    bool? locked,
    Set<String>? hiddenIn,
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
    if (hiddenIn.isNotEmpty) 'hiddenIn': hiddenIn.toList(),
    if (this case ChartText(:final text)) 'text': text,
    if (this case ChartFibRetracement(:final levels) || ChartFibExtension(:final levels))
      'levels': [for (final level in levels) level.toJson()],
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
    final styled = drawing.copyWith(
      width: (json['width'] as num).toDouble(),
      lineStyle: ChartLineStyle.values.byName(json['lineStyle'] as String),
      locked: json['locked'] as bool,
      hiddenIn: {for (final view in json['hiddenIn'] as List? ?? const []) view as String},
    );
    final levels = [
      for (final level in json['levels'] as List? ?? const []) ChartFibLevel.fromJson(level as Map<String, dynamic>),
    ];
    if (levels.isEmpty) return styled;
    return switch (styled) {
      ChartFibRetracement() => styled.copyWith(levels: levels),
      ChartFibExtension() => styled.copyWith(levels: levels),
      _ => styled,
    };
  }

  @override
  List<Object?> get props => [id, points, color, width, lineStyle, selected, locked, hiddenIn];
}

/// One level of a Fibonacci drawing: its ratio, whether it is drawn, and
/// its colour when it is not the drawing's.
class ChartFibLevel extends Equatable {
  const ChartFibLevel(this.ratio, {this.color, this.visible = true});

  factory ChartFibLevel.fromJson(Map<String, dynamic> json) => ChartFibLevel(
    (json['ratio'] as num).toDouble(),
    color: switch (json['color']) {
      final int value => Color(value),
      _ => null,
    },
    visible: json['visible'] as bool? ?? true,
  );

  final double ratio;
  final Color? color;
  final bool visible;

  ChartFibLevel copyWith({Color? color, bool? visible}) =>
      ChartFibLevel(ratio, color: color ?? this.color, visible: visible ?? this.visible);

  Map<String, dynamic> toJson() => {'ratio': ratio, 'color': ?color?.toARGB32(), 'visible': visible};

  @override
  List<Object?> get props => [ratio, color, visible];
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
  measure(2),
  polyline(2, open: true);

  const ChartDrawingTool(this.pointCount, {this.open = false});

  /// The points it takes, the fewest for an [open] one.
  final int pointCount;

  /// Takes any number of points from [pointCount] on, finished by placing
  /// one on the last.
  final bool open;

  /// A new drawing of this kind; a Fibonacci one's levels take the colour
  /// of the level of the same ratio in [fibLevels].
  ChartDrawing create({
    required Object id,
    required List<Coordinates> points,
    required Color color,
    String text = '',
    List<ChartFibLevel> fibLevels = const [],
  }) {
    assert(open ? points.length >= pointCount : points.length == pointCount);
    List<ChartFibLevel> levels(List<ChartFibLevel> defaults) => [
      for (final level in defaults)
        ChartFibLevel(level.ratio, color: fibLevels.where((l) => l.ratio == level.ratio).firstOrNull?.color),
    ];
    return switch (this) {
      trendLine => ChartTrendLine(id: id, points: points, color: color),
      ray => ChartRay(id: id, points: points, color: color),
      extendedLine => ChartExtendedLine(id: id, points: points, color: color),
      horizontalLine => ChartHorizontalLine(id: id, points: points, color: color),
      horizontalRay => ChartHorizontalRay(id: id, points: points, color: color),
      verticalLine => ChartVerticalLine(id: id, points: points, color: color),
      rectangle => ChartRectangle(id: id, points: points, color: color),
      parallelChannel => ChartParallelChannel(id: id, points: points, color: color),
      fibRetracement => ChartFibRetracement(
        id: id,
        points: points,
        color: color,
        levels: levels(ChartFibRetracement.defaultLevels),
      ),
      fibExtension => ChartFibExtension(
        id: id,
        points: points,
        color: color,
        levels: levels(ChartFibExtension.defaultLevels),
      ),
      ChartDrawingTool.text => ChartText(id: id, points: points, color: color, text: text),
      measure => ChartMeasure(id: id, points: points, color: color),
      polyline => ChartPolyline(id: id, points: points, color: color),
    };
  }
}

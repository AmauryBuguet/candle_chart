import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

import '../models/chart_drawing.dart';
import '../models/coordinates.dart';
import 'candle_time.dart';
import 'chart_layout.dart';
import 'chart_viewport.dart';
import 'drawing_geometry.dart';

/// The user's drawings on one chart: placing a tool's points — with the
/// pointer, or on a phone with a cursor — selecting, dragging, and where an
/// aimed point lands on the candle grid and to the magnet. Fed pointer
/// positions by [ChartController].
abstract class ChartDrawingInput extends ChartViewport {
  ChartDrawingInput({
    required super.interval,
    required super.viewConfig,
    required super.candles,
    required super.viewResetKey,
    required super.formatPrice,
    required super.labelStyle,
    required super.indicators,
    required super.colors,
  });

  /// Whether the pointer down is a finger, which hits drawings with more
  /// slack than a mouse. Set by the pointer handling.
  @protected
  bool touch = false;

  /// On a phone a tool is aimed with a cursor rather than the finger: it
  /// starts in the middle of the price pane, swipes anywhere move it by as
  /// much, a tap places the point under it. Set by the widget.
  bool cursorPlacement = false;
  Offset? _cursor;

  /// A mouse held down after placing a point: it keeps aiming the next
  /// one, the crosshair and the preview following it as they do a hover.
  bool _holdingAfterPlace = false;

  @protected
  bool get holdingAfterPlace => _holdingAfterPlace;

  /// Whether the crosshair drawn is the cursor.
  bool get aiming => cursorPlacement && activeTool != null;

  @protected
  Offset placementCursor(Size size) => _cursor ??= layoutFor(size).priceRect.center;

  /// Where the tool's next point would come from: the cursor on a phone,
  /// the pointer otherwise.
  Offset? _aimFor(Size size) => aiming ? placementCursor(size) : crosshairPosition;

  /// The host's drawings and the tool in hand, fed from the widget.
  List<ChartDrawing> get drawings => _drawings;
  List<ChartDrawing> _drawings = const [];
  set drawings(List<ChartDrawing> value) {
    if (value.where((d) => d.selected).firstOrNull?.id != selectedDrawing?.id) _handleSpot = null;
    _drawings = value;
  }

  ChartDrawingTool? activeTool;
  bool magnet = true;
  double magnetReach = 30;

  /// Shift held: a point aimed after another — the tool's next, a dragged
  /// anchor — keeps that other point's time or price, whichever is nearer.
  bool get axisLock => _axisLock;
  bool _axisLock = false;
  set axisLock(bool value) {
    if (value == _axisLock) return;
    _axisLock = value;
    notifyListeners();
  }

  void Function(ChartDrawing drawing)? onDrawingCreated;
  void Function(ChartDrawing drawing)? onDrawingChanged;
  void Function(Object? id)? onDrawingSelected;
  void Function(Object id)? onDrawingDeleted;
  VoidCallback? onDrawingCancelled;
  ChartDrawing Function(ChartDrawing drawing)? styleDrawing;

  /// The points placed so far with [activeTool].
  List<Coordinates> _placed = const [];

  /// The drawing under a pressed pointer: which one, which anchor (none for
  /// its body), and where the pointer went down.
  ({ChartDrawing original, int? anchor, Coordinates from})? _dragging;

  ChartDrawing? get selectedDrawing => drawings.where((d) => d.selected).firstOrNull;

  /// The middle of the price pane when the selected drawing was selected:
  /// a horizontal line's handle keeps its time there, a vertical line's its
  /// price.
  Coordinates? _handleSpot;

  Coordinates? handleSpotFor(Size size) {
    if (selectedDrawing == null) return null;
    final projection = projectionFor(size);
    return _handleSpot ??= projection.coordinatesOf(projection.rect.center);
  }

  /// The drawing being placed, its next point following the pointer, or
  /// nothing when no tool is in hand or no point is down yet.
  ChartDrawing? placingFor(Size size) {
    final tool = activeTool;
    if (tool == null || _placed.isEmpty) return null;
    final pointer = _aimFor(size);
    final next = pointer == null ? _placed.last : _aimed(eventPosition(pointer, size), size, from: _placed.last);
    final missing = tool.open ? 1 : tool.pointCount - _placed.length;
    final points = [..._placed, for (var i = 0; i < missing; i++) next];
    return _styled(tool.create(id: '_placing', points: points, color: colors.drawing, fibLevels: colors.fibLevels));
  }

  /// Drops the tool's half-placed points and the selection, and tells the
  /// host, which may put the tool down.
  void cancelDrawing() {
    _placed = const [];
    if (selectedDrawing != null) onDrawingSelected?.call(null);
    onDrawingCancelled?.call();
    notifyListeners();
  }

  /// Drops the half-placed points and puts the cursor back in the middle.
  @protected
  void resetPlacement() {
    _placed = const [];
    _cursor = null;
  }

  /// Lets go of whatever drawing the pointer held.
  @protected
  void releaseDrawing() {
    _dragging = null;
    _holdingAfterPlace = false;
  }

  void deleteSelectedDrawing() {
    final selected = selectedDrawing;
    if (selected != null) onDrawingDeleted?.call(selected.id);
  }

  /// Whether a mouse going down at [position] was for a drawing: placing
  /// a point with the tool in hand, grabbing the selected one to move it,
  /// or selecting the one under it — which moves only from the next click.
  @protected
  bool drawingPointerDown(Offset position, Size size) {
    final tool = activeTool;
    if (tool != null) {
      place(tool, position, size);
      _holdingAfterPlace = true;
      return true;
    }
    if (grabSelectedDrawing(position, size)) return true;
    final hit = drawingAt(position, size);
    if (hit != null) {
      if (!hit.selected) onDrawingSelected?.call(hit.id);
      return true;
    }
    if (selectedDrawing != null) onDrawingSelected?.call(null);
    return false;
  }

  DrawingHitTolerance get _tolerance => touch ? DrawingHitTolerance.touch : DrawingHitTolerance.mouse;

  /// The mouse cursor over the chart: how the selected drawing under the
  /// pointer would move, a hand over one a click would select, the arrow
  /// elsewhere. Kept while a drawing is being dragged.
  MouseCursor cursorFor(Size size) {
    final drag = _dragging;
    if (drag != null) return _moveCursor(drag.original, drag.anchor);
    final position = crosshairPosition;
    if (position == null || activeTool != null) return MouseCursor.defer;
    final selected = selectedDrawing;
    if (selected != null && !selected.locked) {
      final hit = hitTestDrawing(
        selected,
        position,
        projectionFor(size),
        handles: true,
        tolerance: _tolerance,
        textSize: _textSize,
        handleAt: handleSpotFor(size),
      );
      if (hit != null) return _moveCursor(selected, hit.anchor);
    }
    if (drawingAt(position, size) != null) return SystemMouseCursors.click;
    return MouseCursor.defer;
  }

  static MouseCursor _moveCursor(ChartDrawing drawing, int? anchor) => switch (handleAxis(drawing, anchor)) {
    DrawingHandleAxis.vertical => SystemMouseCursors.resizeUpDown,
    DrawingHandleAxis.horizontal => SystemMouseCursors.resizeLeftRight,
    DrawingHandleAxis.free => SystemMouseCursors.move,
  };

  /// The topmost drawing under [position], by its body.
  @protected
  ChartDrawing? drawingAt(Offset position, Size size) {
    final projection = projectionFor(size);
    for (final drawing in drawings.reversed) {
      if (hitTestDrawing(drawing, position, projection, handles: false, tolerance: _tolerance, textSize: _textSize) !=
          null) {
        return drawing;
      }
    }
    return null;
  }

  /// Places the tool's next point at [position]; the last one creates the
  /// drawing. An open tool's point placed on its last one finishes it
  /// instead.
  @protected
  void place(ChartDrawingTool tool, Offset position, Size size) {
    final point = _aimed(eventPosition(position, size), size, from: _placed.lastOrNull);
    final last = _placed.lastOrNull;
    if (tool.open && last != null) {
      final projection = projectionFor(size);
      if ((projection.offsetOf(point) - projection.offsetOf(last)).distance <= _tolerance.handle) {
        finishDrawing();
        return;
      }
    }
    _placed = [..._placed, point];
    if (!tool.open && _placed.length == tool.pointCount) _create(tool);
    notifyListeners();
  }

  /// Creates an open tool's drawing from the points placed so far, when
  /// there are enough of them.
  void finishDrawing() {
    final tool = activeTool;
    if (tool == null || !tool.open || _placed.length < tool.pointCount) return;
    _create(tool);
    notifyListeners();
  }

  ChartDrawing _styled(ChartDrawing drawing) => styleDrawing?.call(drawing) ?? drawing;

  void _create(ChartDrawingTool tool) {
    onDrawingCreated?.call(
      _styled(
        tool.create(
          id: 'drawing-${DateTime.now().microsecondsSinceEpoch}',
          points: _placed,
          color: colors.drawing,
          fibLevels: colors.fibLevels,
        ),
      ),
    );
    _placed = const [];
  }

  /// Takes hold of the selected drawing, by an anchor or its body, when the
  /// pointer went down on it and it is not locked.
  @protected
  bool grabSelectedDrawing(Offset position, Size size) {
    final selected = selectedDrawing;
    if (selected == null || selected.locked) return false;
    final projection = projectionFor(size);
    final hit = hitTestDrawing(
      selected,
      position,
      projection,
      handles: true,
      tolerance: _tolerance,
      textSize: _textSize,
      handleAt: handleSpotFor(size),
    );
    if (hit == null) return false;
    _dragging = (original: selected, anchor: hit.anchor, from: projection.coordinatesOf(position));
    return true;
  }

  /// Carries the cursor by [delta], kept within the price pane.
  @protected
  void moveCursorBy(Offset delta, Size size) {
    _cursor = offsetWithin(placementCursor(size) + delta, layoutFor(size).priceRect);
    notifyListeners();
  }

  /// Moves the grabbed anchor to the pointer, or the whole drawing by how
  /// far the pointer has come since it went down — whole intervals, so its
  /// points stay on the candle grid.
  @protected
  bool drawingPointerMove(Offset position, Size size) {
    final drag = _dragging;
    if (drag == null) return false;
    final projection = projectionFor(size);
    final now = projection.coordinatesOf(position);
    final List<Coordinates> points;
    if (drag.anchor != null) {
      points = movedAnchor(
        drag.original,
        drag.anchor!,
        _aimed(now, size, from: _neighbourOf(drag.original, drag.anchor!)),
      );
    } else {
      final dt = _onCandle(now.timestamp) - _onCandle(drag.from.timestamp);
      final ratio = viewConfig.logScale && drag.from.price > 0 ? now.price / drag.from.price : null;
      final dp = now.price - drag.from.price;
      points = [
        for (final p in drag.original.points)
          Coordinates(timestamp: _moved(p.timestamp, dt), price: ratio != null ? p.price * ratio : p.price + dp),
      ];
    }
    onDrawingChanged?.call(drag.original.copyWith(points: points));
    return true;
  }

  /// Where the crosshair is drawn: on the pointer, or with a tool in hand
  /// on the point the next placement would take — the cursor's on a phone
  /// — so the magnet's pull shows.
  Offset? crosshairFor(Size size) {
    final pointer = _aimFor(size);
    if (pointer == null || activeTool == null) return pointer;
    final raw = eventPosition(pointer, size);
    final aimed = _aimed(raw, size, from: _placed.lastOrNull);
    return aimed == raw ? pointer : projectionFor(size).offsetOf(aimed);
  }

  /// The point a dragged anchor is locked against: the one before it, the
  /// second for the first; none for a rectangle's derived corners.
  static Coordinates? _neighbourOf(ChartDrawing drawing, int anchor) {
    final points = drawing.points;
    if (anchor >= points.length || points.length < 2) return null;
    return points[anchor == 0 ? 1 : anchor - 1];
  }

  /// Where a point aimed at [c] lands: locked to [from]'s time or price —
  /// whichever is nearer on screen — while [axisLock] holds and there is a
  /// [from], then on the grid and to the magnet. A price lock beats the
  /// magnet, which would pull the point off the line.
  Coordinates _aimed(Coordinates c, Size size, {required Coordinates? from}) {
    if (!axisLock || from == null) return _snapped(c, size);
    final projection = projectionFor(size);
    final dx = (projection.xForTime(c.timestamp) - projection.xForTime(from.timestamp)).abs();
    final dy = (projection.yForPrice(c.price) - projection.yForPrice(from.price)).abs();
    if (dx < dy) return _snapped(Coordinates(timestamp: from.timestamp, price: c.price), size);
    return Coordinates(timestamp: _onCandle(c.timestamp), price: from.price);
  }

  /// A point lands on the candle grid in time, as the crosshair aligns.
  /// With the magnet on, over a candle it also lands on its open, high,
  /// low or close when one is within [magnetReach].
  Coordinates _snapped(Coordinates c, Size size) {
    final onGrid = Coordinates(timestamp: _onCandle(c.timestamp), price: c.price);
    if (!magnet || candles.isEmpty) return onGrid;
    final index = firstCandleFrom(onGrid.timestamp, candles);
    if (index == candles.length || candles[index].timestamp != onGrid.timestamp) return onGrid;
    final candle = candles[index];
    final projection = projectionFor(size);
    final y = projection.yForPrice(c.price);
    double? best;
    var bestDistance = magnetReach;
    for (final level in [candle.open, candle.high, candle.low, candle.close]) {
      final distance = (projection.yForPrice(level) - y).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = level;
      }
    }
    if (best == null) return onGrid;
    return Coordinates(timestamp: candle.timestamp, price: best);
  }

  /// [time] moved by [dt]; a point on a candle's open stays on one, as
  /// candles of uneven length, calendar months, do not all move by [dt].
  int _moved(int time, int dt) {
    final moved = time + dt;
    return candles.isNotEmpty && candleTimeOf(time, candles) == time ? _onCandle(moved) : moved;
  }

  /// [time] on the nearest candle's open, or on the interval grid with none.
  int _onCandle(int time) => candles.isEmpty ? _onInterval(time) : nearestCandleTime(time, candles);

  /// [time] rounded to the nearest whole interval.
  int _onInterval(int time) {
    final interval = this.interval.inMilliseconds;
    return interval == 0 ? time : (time / interval).round() * interval;
  }

  Size _textSize(ChartText text) => (TextPainter(
    text: TextSpan(text: text.text, style: labelStyle.textStyle),
    textDirection: TextDirection.ltr,
  )..layout()).size;
}

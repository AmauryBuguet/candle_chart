import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../models/axis.dart';
import '../models/chart_candle.dart';
import '../models/chart_colors.dart';
import '../models/chart_drawing.dart';
import '../models/chart_indicator.dart';
import '../models/chart_label_style.dart';
import '../models/chart_margins.dart';
import '../models/chart_view_config.dart';
import '../models/coordinates.dart';
import 'chart_layout.dart';
import 'drawing_geometry.dart';
import 'event_origin.dart';
import 'indicator_compute.dart';
import 'indicator_render.dart';
import 'pane_axis.dart';
import 'price_axis_engine.dart';
import 'price_scale.dart';
import 'time_axis_engine.dart';

/// Owns a single chart's view interaction: pan, zoom (wheel + pinch),
/// crosshair, and margin sizing.
///
/// Selection/dragging of chart objects (lines, orders) is delegated to the
/// host via the callbacks passed into [onPointerDown]/[onPointerMove] — this
/// controller never knows what a "line" or "order" is. Plain [ChangeNotifier]
/// on purpose: this state is local to one [TradingChart] instance, so there's
/// no need for an app-wide state management dependency.
class ChartController extends ChangeNotifier {
  ChartController({
    required Duration interval,
    required ChartViewConfig viewConfig,
    required List<ChartCandle> candles,
    required Object viewResetKey,
    required String Function(double price) formatPrice,
    required ChartLabelStyle labelStyle,
    required List<ChartIndicator> indicators,
    required ChartColors colors,
  }) : _interval = interval,
       _viewConfig = viewConfig,
       _candles = candles,
       _viewResetKey = viewResetKey,
       _formatPrice = formatPrice,
       _labelStyle = labelStyle,
       _indicators = indicators,
       _colors = colors,
       _timeAxisEngine = TimeAxisEngine(interval: interval, viewConfig: viewConfig) {
    _priceAxisEngine.recompute(
      candles: _candles,
      timeAxis: timeAxis,
      priceMargin: _viewConfig.priceMargin,
      logScale: _viewConfig.logScale,
    );
    _recomputeIndicators();
    _syncPanes();
    margins = _computeMargins();
  }

  final TimeAxisEngine _timeAxisEngine;
  final PriceAxisEngine _priceAxisEngine = PriceAxisEngine();

  Duration _interval;
  ChartViewConfig _viewConfig;
  List<ChartCandle> _candles;
  Object _viewResetKey;
  String Function(double price) _formatPrice;
  ChartLabelStyle _labelStyle;
  List<ChartIndicator> _indicators;
  ChartColors _colors;

  EventOrigin _eventOrigin = EventOrigin.other;
  int? _draggedHandle;
  double? _lastHorizontalScale;

  /// The pointer that is down — the first finger, a second one being a
  /// pinch — whether it is a finger, where it went down and whether it has
  /// moved past the slop since: a finger lifted without moving is a tap.
  int? _pointer;
  bool _touch = false;
  Offset? _downPosition;
  EventOrigin _downOrigin = EventOrigin.other;
  bool _dragged = false;

  /// Under a finger the crosshair is a mode: a tap on nothing shows it
  /// there, swipes anywhere then move it by as much from where it is, and
  /// a tap anywhere hides it. A mouse hovers instead.
  bool _crosshairPinned = false;
  bool _movingCrosshair = false;

  /// On a phone a tool is aimed with a cursor rather than the finger: it
  /// starts in the middle of the price pane, swipes anywhere move it by as
  /// much, a tap places the point under it. Set by the widget.
  bool cursorPlacement = false;
  Offset? _cursor;
  bool _movingCursor = false;

  /// A mouse held down after placing a point: it keeps aiming the next
  /// one, the crosshair and the preview following it as they do a hover.
  bool _holdingAfterPlace = false;

  /// Whether the crosshair drawn is the cursor.
  bool get aiming => cursorPlacement && activeTool != null;

  Offset _cursorFor(Size size) => _cursor ??= layoutFor(size).priceRect.center;

  /// Where the tool's next point would come from: the cursor on a phone,
  /// the pointer otherwise.
  Offset? _aimFor(Size size) => aiming ? _cursorFor(size) : crosshairPosition;

  /// Told the timestamp of the oldest candle when the view nears it, once
  /// per oldest candle, so the host can fetch what comes before.
  void Function(int before)? onNeedMoreHistory;
  int? _historyRequestedBefore;

  /// The host's drawings and the tool in hand, fed from the widget.
  List<ChartDrawing> drawings = const [];
  ChartDrawingTool? activeTool;
  bool magnet = true;

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

  /// The points placed so far with [activeTool].
  List<Coordinates> _placed = const [];

  /// The drawing under a pressed pointer: which one, which anchor (none for
  /// its body), and where the pointer went down.
  ({ChartDrawing original, int? anchor, Coordinates from})? _dragging;

  ChartDrawing? get selectedDrawing => drawings.where((d) => d.selected).firstOrNull;

  /// The drawing being placed, its next point following the pointer, or
  /// nothing when no tool is in hand or no point is down yet.
  ChartDrawing? placingFor(Size size) {
    final tool = activeTool;
    if (tool == null || _placed.isEmpty) return null;
    final pointer = _aimFor(size);
    final next = pointer == null ? _placed.last : _aimed(_getEventPosition(pointer, size), size, from: _placed.last);
    final points = [..._placed, for (var i = _placed.length; i < tool.pointCount; i++) next];
    return tool.create(id: '_placing', points: points, color: _colors.drawing);
  }

  /// Drops the tool's half-placed points and the selection, and tells the
  /// host, which may put the tool down.
  void cancelDrawing() {
    _placed = const [];
    if (selectedDrawing != null) onDrawingSelected?.call(null);
    onDrawingCancelled?.call();
    notifyListeners();
  }

  /// The tool changed hands, mid-build: the half-placed points go, the
  /// cursor starts over, and on a phone the crosshair is put away for it.
  /// Touches neither the selection nor the listeners.
  void toolChanged() {
    _placed = const [];
    _cursor = null;
    if (aiming && _crosshairPinned) {
      _crosshairPinned = false;
      crosshairPosition = null;
    }
  }

  void deleteSelectedDrawing() {
    final selected = selectedDrawing;
    if (selected != null) onDrawingDeleted?.call(selected.id);
  }

  DrawingProjection projectionFor(Size size) {
    final rect = layoutFor(size).priceRect;
    return DrawingProjection(
      rect: rect,
      xForTime: (t) => rect.left + (t - timeAxis.start) / timeAxis.range * rect.width,
      yForPrice: (p) => yForPrice(p, priceAxis, rect, logScale: _viewConfig.logScale),
      timeForX: (x) => timeAxis.start + ((x - rect.left) / rect.width * timeAxis.range).round(),
      priceForY: (y) => priceForY(y, priceAxis, rect, logScale: _viewConfig.logScale),
    );
  }

  /// Whether a mouse going down at [position] was for a drawing: placing
  /// a point with the tool in hand, grabbing the selected one to move it,
  /// or selecting the one under it — which moves only from the next click.
  bool _drawingPointerDown(Offset position, Size size) {
    final tool = activeTool;
    if (tool != null) {
      _place(tool, position, size);
      _holdingAfterPlace = true;
      return true;
    }
    if (_grabSelectedDrawing(position, size)) return true;
    final hit = _drawingAt(position, size);
    if (hit != null) {
      if (!hit.selected) onDrawingSelected?.call(hit.id);
      return true;
    }
    if (selectedDrawing != null) onDrawingSelected?.call(null);
    return false;
  }

  DrawingHitTolerance get _tolerance => _touch ? DrawingHitTolerance.touch : DrawingHitTolerance.mouse;

  /// The mouse cursor over the chart: how the selected drawing under the
  /// pointer would move, a hand over one a click would select, the arrow
  /// elsewhere. Kept while a drawing is being dragged.
  MouseCursor cursorFor(Size size) {
    final drag = _dragging;
    if (drag != null) return _moveCursor(drag.original);
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
      );
      if (hit != null) return _moveCursor(selected);
    }
    if (_drawingAt(position, size) != null) return SystemMouseCursors.click;
    return MouseCursor.defer;
  }

  static MouseCursor _moveCursor(ChartDrawing drawing) => switch (drawing) {
    ChartHorizontalLine() || ChartHorizontalRay() => SystemMouseCursors.resizeUpDown,
    ChartVerticalLine() => SystemMouseCursors.resizeLeftRight,
    _ => SystemMouseCursors.move,
  };

  /// The topmost drawing under [position], by its body.
  ChartDrawing? _drawingAt(Offset position, Size size) {
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
  /// drawing.
  void _place(ChartDrawingTool tool, Offset position, Size size) {
    _placed = [..._placed, _aimed(_getEventPosition(position, size), size, from: _placed.lastOrNull)];
    if (_placed.length == tool.pointCount) {
      onDrawingCreated?.call(
        tool.create(id: 'drawing-${DateTime.now().microsecondsSinceEpoch}', points: _placed, color: _colors.drawing),
      );
      _placed = const [];
    }
    notifyListeners();
  }

  /// Takes hold of the selected drawing, by an anchor or its body, when the
  /// pointer went down on it and it is not locked.
  bool _grabSelectedDrawing(Offset position, Size size) {
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
    );
    if (hit == null) return false;
    _dragging = (original: selected, anchor: hit.anchor, from: projection.coordinatesOf(position));
    return true;
  }

  /// A finger's tap: aiming, places the tool's point under the cursor;
  /// with the crosshair up, hides it, wherever the tap. Otherwise places
  /// the tool's point, selects the drawing under it, drops the selection
  /// if there is one, or on nothing shows the crosshair there.
  void _touchTap(Offset position, Size size) {
    if (aiming) {
      _place(activeTool!, _cursorFor(size), size);
      return;
    }
    if (_crosshairPinned) {
      _crosshairPinned = false;
      setCrosshairPosition(null);
      return;
    }
    if (_downOrigin != EventOrigin.chart && _downOrigin != EventOrigin.pane) return;
    final tool = activeTool;
    if (tool != null) {
      if (_downOrigin == EventOrigin.chart) _place(tool, position, size);
      return;
    }
    if (_downOrigin == EventOrigin.chart) {
      final hit = _drawingAt(position, size);
      if (hit != null) {
        if (!hit.selected) onDrawingSelected?.call(hit.id);
        return;
      }
      if (selectedDrawing != null) {
        onDrawingSelected?.call(null);
        return;
      }
    }
    _crosshairPinned = true;
    setCrosshairPosition(position);
  }

  /// Carries the pinned crosshair by [delta], kept within the plot.
  void _moveCrosshairBy(Offset delta, Size size) {
    final current = crosshairPosition;
    if (current == null) return;
    setCrosshairPosition(_within(current + delta, layoutFor(size).plotRect));
  }

  /// Carries the cursor by [delta], kept within the price pane.
  void _moveCursorBy(Offset delta, Size size) {
    _cursor = _within(_cursorFor(size) + delta, layoutFor(size).priceRect);
    notifyListeners();
  }

  static Offset _within(Offset point, Rect rect) =>
      Offset(point.dx.clamp(rect.left, rect.right), point.dy.clamp(rect.top, rect.bottom));

  /// Moves the grabbed anchor to the pointer, or the whole drawing by how
  /// far the pointer has come since it went down — whole intervals, so its
  /// points stay on the candle grid.
  bool _drawingPointerMove(Offset position, Size size) {
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
      final dt = _onInterval(now.timestamp - drag.from.timestamp);
      final ratio = _viewConfig.logScale && drag.from.price > 0 ? now.price / drag.from.price : null;
      final dp = now.price - drag.from.price;
      points = [
        for (final p in drag.original.points)
          Coordinates(timestamp: p.timestamp + dt, price: ratio != null ? p.price * ratio : p.price + dp),
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
    final raw = _getEventPosition(pointer, size);
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
    return Coordinates(timestamp: _onInterval(c.timestamp), price: from.price);
  }

  /// How far in pixels the magnet reaches, in price only.
  static const magnetReach = 30.0;

  /// A point lands on the candle grid in time, as the crosshair aligns.
  /// With the magnet on, over a candle it also lands on its open, high,
  /// low or close when one is within [magnetReach].
  Coordinates _snapped(Coordinates c, Size size) {
    final onGrid = Coordinates(timestamp: _onInterval(c.timestamp), price: c.price);
    if (!magnet || _candles.isEmpty) return onGrid;
    final halfInterval = _interval.inMilliseconds ~/ 2;
    final index = _firstCandleFrom(c.timestamp - halfInterval);
    if (index == _candles.length || _candles[index].timestamp - halfInterval > c.timestamp) return onGrid;
    final candle = _candles[index];
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

  /// [time] — or a span of time — rounded to the nearest whole interval.
  int _onInterval(int time) {
    final interval = _interval.inMilliseconds;
    return interval == 0 ? time : (time / interval).round() * interval;
  }

  /// The index of the first candle at or after [timestamp], by bisection.
  int _firstCandleFrom(int timestamp) {
    var low = 0, high = _candles.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_candles[mid].timestamp < timestamp) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  Size _textSize(ChartText text) => (TextPainter(
    text: TextSpan(text: text.text, style: _labelStyle.textStyle),
    textDirection: TextDirection.ltr,
  )..layout()).size;

  TimeAxis get timeAxis => _timeAxisEngine.axis;
  PriceAxis get priceAxis => _priceAxisEngine.axis;
  late ChartMargins margins;
  Offset? crosshairPosition;

  /// The series of every indicator, computed once per candle list.
  final Map<ChartIndicator, IndicatorRender> _renders = {};

  /// Each pane's share of the plot height, the same order as [paneIndicators].
  List<double> paneFractions = const [];

  /// Each pane's value axis, fitted to what is visible.
  List<PriceAxis> paneAxes = const [];

  List<ChartOverlay> get overlays => [
    for (final i in _indicators)
      if (i is ChartOverlay) i,
  ];
  List<ChartPaneIndicator> get paneIndicators => [
    for (final i in _indicators)
      if (i is ChartPaneIndicator) i,
  ];

  IndicatorRender renderOf(ChartIndicator indicator) => _renders[indicator]!;

  ChartLayout layoutFor(Size size) => ChartLayout(size: size, margins: margins, paneFractions: paneFractions);

  static const _candlesEquality = ListEquality<ChartCandle>();
  static const _indicatorsEquality = ListEquality<ChartIndicator>();

  /// Feeds updated widget-level inputs in. Call from `didUpdateWidget`.
  ///
  /// [TradingChart]'s host rebuilds it on every change to any of its own
  /// state (lines, orders, positions, settings...), not just when something
  /// relevant to the chart's own view actually changed — so this only does
  /// real work (and repaints) when [interval]/[viewConfig] actually differ,
  /// [candles] actually differ by value (a fresh `.toList()` each rebuild
  /// would otherwise always look "changed"), or [viewResetKey] changed.
  void updateInputs({
    required Duration interval,
    required ChartViewConfig viewConfig,
    required List<ChartCandle> candles,
    required Object viewResetKey,
    required String Function(double price) formatPrice,
    required ChartLabelStyle labelStyle,
    required List<ChartIndicator> indicators,
    required ChartColors colors,
  }) {
    _formatPrice = formatPrice;
    final labelStyleChanged = labelStyle != _labelStyle;
    _labelStyle = labelStyle;
    final indicatorsChanged = !_indicatorsEquality.equals(indicators, _indicators) || colors != _colors;
    _indicators = indicators;
    _colors = colors;

    // Only what shapes the time window resets it; a scale or margin change
    // refits the prices under the same view.
    var timeAxisReset = false;
    var priceAxisReset = false;
    if (interval != _interval || !viewConfig.sameTimeWindow(_viewConfig)) {
      _timeAxisEngine.reset(interval: interval, viewConfig: viewConfig);
      timeAxisReset = true;
    } else if (viewConfig != _viewConfig) {
      _priceAxisEngine.anchored = true;
      priceAxisReset = true;
    }
    _interval = interval;
    _viewConfig = viewConfig;

    var resetKeyChanged = false;
    if (viewResetKey != _viewResetKey) {
      _viewResetKey = viewResetKey;
      _priceAxisEngine.anchored = true;
      resetKeyChanged = true;
    }

    final candlesChanged = !_candlesEquality.equals(candles, _candles);
    _candles = candles;

    if (candlesChanged || indicatorsChanged) {
      _recomputeIndicators();
      _syncPanes();
    }
    if (candlesChanged) _requestHistoryIfNeeded();

    if (timeAxisReset || priceAxisReset || resetKeyChanged || candlesChanged) {
      final beforePrice = priceAxis;
      _refitPriceAxis();
      if (timeAxisReset || priceAxis != beforePrice || indicatorsChanged) {
        margins = _computeMargins();
        notifyListeners();
        return;
      }
    }
    if (labelStyleChanged || indicatorsChanged) {
      margins = _computeMargins();
      notifyListeners();
    }
  }

  /// The view is within twenty candles of the oldest one, or past it: ask
  /// for more, unless already asked for this same oldest candle.
  void _requestHistoryIfNeeded() {
    final callback = onNeedMoreHistory;
    if (callback == null || _candles.isEmpty) return;
    final oldest = _candles.first.timestamp;
    if (timeAxis.start > oldest + 20 * _interval.inMilliseconds) return;
    if (_historyRequestedBefore == oldest) return;
    _historyRequestedBefore = oldest;
    callback(oldest);
  }

  void _recomputeIndicators() {
    _renders
      ..clear()
      ..addEntries([for (final i in _indicators) MapEntry(i, renderIndicator(i, _candles, _colors))]);
  }

  /// Keeps one height per pane across edits to the indicator list: a pane
  /// that is still there keeps its height, a new one takes its indicator's.
  void _syncPanes() {
    final panes = paneIndicators;
    final previous = _previousPanes;
    final fractions = <double>[];
    for (final pane in panes) {
      final index = previous.indexOf(pane);
      fractions.add(index != -1 ? paneFractions[index] : pane.height);
    }
    paneFractions = clampPaneFractions(fractions);
    _previousPanes = panes;
    _refitPaneAxes();
  }

  List<ChartPaneIndicator> _previousPanes = const [];

  void _refitPaneAxes() {
    paneAxes = [
      for (final pane in paneIndicators) fitPaneAxis(render: _renders[pane]!, candles: _candles, timeAxis: timeAxis),
    ];
  }

  void setCrosshairPosition(Offset? position) {
    if (position == crosshairPosition) return;
    crosshairPosition = position;
    notifyListeners();
  }

  void onPointerDown(
    PointerDownEvent event,
    Size size,
    bool isMobile, {
    required void Function(Coordinates pos, PriceAxis priceAxis, TimeAxis timeAxis, bool isMobile) onPointerDownInChart,
    required VoidCallback onPointerDownOutsideChart,
  }) {
    if (_pointer != null && event.pointer != _pointer) {
      // A second finger: a pinch, neither a tap nor a swipe of the crosshair.
      _downPosition = null;
      _movingCrosshair = false;
      return;
    }
    final layout = layoutFor(size);
    final position = event.localPosition;
    _pointer = event.pointer;
    _eventOrigin = _getEventOrigin(position, size, layout);
    _draggedHandle = _eventOrigin == EventOrigin.handle ? layout.handleAt(position) : null;
    _touch = event.kind == PointerDeviceKind.touch;
    _downPosition = position;
    _downOrigin = _eventOrigin;
    _dragged = false;
    if (_touch && aiming) {
      // Wherever it lands: a swipe carries the cursor, a tap places.
      _movingCursor = true;
      _eventOrigin = EventOrigin.other;
      return;
    }
    if (_touch && _crosshairPinned) {
      // Wherever it lands: a swipe carries the crosshair, a tap hides it.
      _movingCrosshair = true;
      _eventOrigin = EventOrigin.other;
      return;
    }
    if (_eventOrigin == EventOrigin.chart) {
      // A touch grabs only the selected drawing; selecting, placing and
      // the crosshair wait for the lift, so a swipe pans whatever it
      // started on.
      final taken = _touch
          ? activeTool == null && _grabSelectedDrawing(position, size)
          : _drawingPointerDown(position, size);
      if (taken) {
        _eventOrigin = EventOrigin.other;
        return;
      }
      if (activeTool == null) onPointerDownInChart(_getEventPosition(position, size), priceAxis, timeAxis, isMobile);
    } else {
      onPointerDownOutsideChart();
    }
    setCrosshairPosition(null);
  }

  /// The pointer lifted: whatever it held is let go; a mouse leaves the
  /// crosshair where it lifted, a touch that never moved is a tap.
  void onPointerUp(PointerUpEvent event, Size size) {
    if (event.pointer != _pointer) return;
    final tapped = _downPosition != null && !_dragged;
    _release();
    if (!_touch) {
      setCrosshairPosition(event.localPosition);
      return;
    }
    if (tapped) _touchTap(event.localPosition, size);
  }

  /// The pointer was taken away — by the system, or a parent gesture.
  void onPointerCancel() => _release();

  void _release() {
    _pointer = null;
    _downPosition = null;
    _dragging = null;
    _movingCrosshair = false;
    _movingCursor = false;
    _holdingAfterPlace = false;
  }

  void onPointerMove(
    PointerMoveEvent event,
    Size size, {
    required bool Function(Coordinates delta, Coordinates coord, PriceAxis priceAxis) onDragUpdate,
  }) {
    final down = _downPosition;
    if (down != null && (event.localPosition - down).distance > kTouchSlop) _dragged = true;
    if (_movingCursor) {
      _moveCursorBy(event.delta, size);
      return;
    }
    if (_movingCrosshair) {
      _moveCrosshairBy(event.delta, size);
      return;
    }
    if (_holdingAfterPlace) {
      setCrosshairPosition(event.localPosition);
      return;
    }
    if (_eventOrigin == EventOrigin.handle) {
      _dragHandle(event.delta.dy, size);
      return;
    }
    if (_drawingPointerMove(event.localPosition, size)) return;
    final delta = _getEventDelta(event.delta, size);
    final coord = _getEventPosition(event.localPosition, size);
    final hasSelected = _eventOrigin == EventOrigin.chart && onDragUpdate(delta, coord, priceAxis);
    if (!hasSelected) {
      final beforeTime = timeAxis;
      final beforePrice = priceAxis;
      final height = layoutFor(size).priceRect.height;
      if (_eventOrigin == EventOrigin.chart || _eventOrigin == EventOrigin.pane) {
        if (_lastHorizontalScale == null) {
          _timeAxisEngine.pan(delta.timestamp);
          if (_eventOrigin == EventOrigin.chart) {
            _priceAxisEngine.panBy(event.delta.dy, height, logScale: _viewConfig.logScale);
          }
          // Panning changes which candles are visible, so an anchored price
          // axis needs to refit to them too — it's not just following the
          // manual pan above (which only applies while un-anchored).
          _refitPriceAxis();
          _requestHistoryIfNeeded();
        }
      } else if (_eventOrigin == EventOrigin.yScale) {
        _priceAxisEngine.scaleBy(event.delta.dy, height, logScale: _viewConfig.logScale);
      }
      if (timeAxis != beforeTime || priceAxis != beforePrice) {
        margins = _computeMargins();
        notifyListeners();
      }
    }
  }

  /// Moving the handle above pane [i] up grows it at the expense of what is
  /// above: the pane before it, or the price pane.
  void _dragHandle(double dy, Size size) {
    final i = _draggedHandle;
    if (i == null) return;
    final layout = layoutFor(size);
    if (layout.plotHeight <= 0) return;
    final delta = -dy / layout.plotHeight;
    final fractions = [...paneFractions];
    fractions[i] += delta;
    if (i > 0) fractions[i - 1] -= delta;
    final clamped = clampPaneFractions(fractions);
    if (const ListEquality<double>().equals(clamped, paneFractions)) return;
    paneFractions = clamped;
    notifyListeners();
  }

  void onPointerSignal(PointerSignalEvent event, Size size) {
    if (event is PointerScrollEvent) {
      final coordinates = _getEventPosition(event.localPosition, size);
      final offset = (timeAxis.range * 0.0005 * event.scrollDelta.dy).toInt();
      final time = min(max(coordinates.timestamp, timeAxis.start), timeAxis.end);
      final percent = (time - timeAxis.start) / timeAxis.range;
      final beforeTime = timeAxis;
      final beforePrice = priceAxis;
      _timeAxisEngine.scale(offset, percent);
      _refitPriceAxis();
      _requestHistoryIfNeeded();
      if (timeAxis != beforeTime || priceAxis != beforePrice) {
        margins = _computeMargins();
        notifyListeners();
      }
    }
  }

  /// Whether the visible window still includes now.
  bool get isLive => _timeAxisEngine.isLive;

  /// Slides the view by [fraction] of its width, right when positive.
  void panByFraction(double fraction) {
    final beforeTime = timeAxis;
    _timeAxisEngine.pan((timeAxis.range * fraction).round());
    _refitPriceAxis();
    _requestHistoryIfNeeded();
    if (timeAxis != beforeTime) {
      margins = _computeMargins();
      notifyListeners();
    }
  }

  /// Zooms the view about its middle, in when [factor] is under one.
  void zoomBy(double factor) {
    final beforeTime = timeAxis;
    _timeAxisEngine.scale((timeAxis.range * (factor - 1)).round(), 0.5);
    _refitPriceAxis();
    _requestHistoryIfNeeded();
    if (timeAxis != beforeTime) {
      margins = _computeMargins();
      notifyListeners();
    }
  }

  /// Brings the view back to the live edge, keeping the current zoom.
  void jumpToLive() {
    final beforeTime = timeAxis;
    final beforePrice = priceAxis;
    _timeAxisEngine.jumpToLive();
    _priceAxisEngine.anchored = true;
    _refitPriceAxis();
    if (timeAxis != beforeTime || priceAxis != beforePrice) {
      margins = _computeMargins();
      notifyListeners();
    }
  }

  void onDoubleTap() {
    final beforeTime = timeAxis;
    final beforePrice = priceAxis;
    final wasAnchored = _priceAxisEngine.anchored;
    if (_eventOrigin == EventOrigin.xScale) {
      _timeAxisEngine.reset(interval: _interval, viewConfig: _viewConfig);
    }
    _priceAxisEngine.anchored = true;
    if (!wasAnchored || _eventOrigin == EventOrigin.xScale) {
      _refitPriceAxis();
    }
    if (timeAxis != beforeTime || priceAxis != beforePrice) {
      margins = _computeMargins();
      notifyListeners();
    }
  }

  /// Refits the price axis to [_candles] within the current [timeAxis].
  /// No-op while the price axis isn't anchored (the user manually
  /// pan/zoomed it) — matches [PriceAxisEngine.recompute]'s own guard.
  void _refitPriceAxis() {
    _priceAxisEngine.recompute(
      candles: _candles,
      timeAxis: timeAxis,
      priceMargin: _viewConfig.priceMargin,
      logScale: _viewConfig.logScale,
    );
    _refitPaneAxes();
  }

  void onScaleStart(ScaleStartDetails details) {
    if (details.pointerCount == 2) {
      _lastHorizontalScale = 1.0;
    }
  }

  void onScaleUpdate(ScaleUpdateDetails details, Size size) {
    if (_lastHorizontalScale != null && details.horizontalScale > 0.05) {
      final timeScaleChange = details.horizontalScale / _lastHorizontalScale!;
      final coordinates = _getEventPosition(details.localFocalPoint, size);
      final time = min(max(coordinates.timestamp, timeAxis.start), timeAxis.end);
      final timePercent = (time - timeAxis.start) / timeAxis.range;
      final beforeTime = timeAxis;
      final beforePrice = priceAxis;
      _timeAxisEngine.scaleMobile(timeScaleChange, timePercent);
      _lastHorizontalScale = details.horizontalScale;
      _refitPriceAxis();
      _requestHistoryIfNeeded();
      if (timeAxis != beforeTime || priceAxis != beforePrice) {
        margins = _computeMargins();
        notifyListeners();
      }
    }
  }

  void onScaleEnd(ScaleEndDetails details) {
    _lastHorizontalScale = null;
  }

  /// UTILS

  EventOrigin _getEventOrigin(Offset position, Size size, ChartLayout layout) {
    if (size.height - position.dy < margins.bottom) return EventOrigin.xScale;
    if (layout.handleAt(position) != null) return EventOrigin.handle;
    if (size.width - position.dx < margins.right) {
      return position.dy < layout.priceRect.bottom ? EventOrigin.yScale : EventOrigin.other;
    }
    if (layout.paneAt(position) != null) return EventOrigin.pane;
    if (layout.priceRect.contains(position)) return EventOrigin.chart;
    return EventOrigin.other;
  }

  Coordinates _getEventPosition(Offset position, Size size) {
    final rect = layoutFor(size).priceRect;
    final price = priceForY(position.dy, priceAxis, rect, logScale: _viewConfig.logScale);
    final int time = timeAxis.start + ((position.dx - rect.left) * timeAxis.range ~/ rect.width);
    return Coordinates(timestamp: time, price: price);
  }

  /// The price delta is what a linear axis would read; under a log scale a
  /// host dragging its own objects should use the transform's mapping.
  Coordinates _getEventDelta(Offset delta, Size size) {
    final rect = layoutFor(size).priceRect;
    final priceDelta = -1 * delta.dy * priceAxis.range / rect.height;
    final int timeDelta = -1 * delta.dx * timeAxis.range ~/ rect.width;
    return Coordinates(timestamp: timeDelta, price: priceDelta);
  }

  ChartMargins _computeMargins() {
    final startPriceStr = _formatPrice(priceAxis.start);
    final endPriceStr = _formatPrice(priceAxis.end);
    final longerPrice = startPriceStr.length > endPriceStr.length ? startPriceStr : endPriceStr;
    final tp = TextPainter(
      text: TextSpan(text: longerPrice, style: _labelStyle.textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    return ChartMargins(
      right: _labelStyle.labelMargin + tp.size.width + _labelStyle.labelMargin,
      left: 0,
      top: tp.size.height / 2 + 1,
      bottom: tp.size.height + 5,
    );
  }
}

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
    _priceAxisEngine.recompute(candles: _candles, timeAxis: timeAxis, priceMargin: _viewConfig.priceMargin);
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

  /// Told the timestamp of the oldest candle when the view nears it, once
  /// per oldest candle, so the host can fetch what comes before.
  void Function(int before)? onNeedMoreHistory;
  int? _historyRequestedBefore;

  /// The host's drawings and the tool in hand, fed from the widget.
  List<ChartDrawing> drawings = const [];
  ChartDrawingTool? activeTool;
  bool magnet = true;
  void Function(ChartDrawing drawing)? onDrawingCreated;
  void Function(ChartDrawing drawing)? onDrawingChanged;
  void Function(Object? id)? onDrawingSelected;
  void Function(Object id)? onDrawingDeleted;

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
    final pointer = crosshairPosition;
    final next = pointer == null ? _placed.last : _snapped(_getEventPosition(pointer, size), size);
    final points = [..._placed, for (var i = _placed.length; i < tool.pointCount; i++) next];
    return tool.create(id: '_placing', points: points, color: _colors.drawing);
  }

  /// Ends whatever the pointer was doing to a drawing; the host commits on
  /// its own `onDragEnd`.
  void endDrawingDrag() => _dragging = null;

  /// Drops the tool's half-placed points and the selection.
  void cancelDrawing() {
    _placed = const [];
    if (selectedDrawing != null) onDrawingSelected?.call(null);
    notifyListeners();
  }

  /// Drops the tool's half-placed points without touching the selection or
  /// notifying — for when the host swaps the tool, mid-build.
  void dropPlacement() => _placed = const [];

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

  /// Whether a pointer going down at [position] was for a drawing: placing
  /// a point with the tool in hand, or grabbing one to select or move it.
  bool _drawingPointerDown(Offset position, Size size) {
    final tool = activeTool;
    if (tool != null) {
      _placed = [..._placed, _snapped(_getEventPosition(position, size), size)];
      if (_placed.length == tool.pointCount) {
        onDrawingCreated?.call(
          tool.create(id: 'drawing-${DateTime.now().microsecondsSinceEpoch}', points: _placed, color: _colors.drawing),
        );
        _placed = const [];
      }
      notifyListeners();
      return true;
    }
    final projection = projectionFor(size);
    final selected = selectedDrawing;
    if (selected != null && !selected.locked) {
      final hit = hitTestDrawing(selected, position, projection, handles: true, textSize: _textSize);
      if (hit != null) {
        _dragging = (original: selected, anchor: hit.anchor, from: projection.coordinatesOf(position));
        return true;
      }
    }
    for (final drawing in drawings.reversed) {
      if (hitTestDrawing(drawing, position, projection, handles: false, textSize: _textSize) == null) continue;
      if (!drawing.locked) {
        _dragging = (original: drawing, anchor: null, from: projection.coordinatesOf(position));
      }
      if (!drawing.selected) onDrawingSelected?.call(drawing.id);
      return true;
    }
    if (selected != null) onDrawingSelected?.call(null);
    return false;
  }

  /// Moves the grabbed anchor to the pointer, or the whole drawing by how
  /// far the pointer has come since it went down.
  bool _drawingPointerMove(Offset position, Size size) {
    final drag = _dragging;
    if (drag == null) return false;
    final projection = projectionFor(size);
    final now = projection.coordinatesOf(position);
    final List<Coordinates> points;
    if (drag.anchor != null) {
      points = [...drag.original.points];
      points[drag.anchor!] = _snapped(now, size);
    } else {
      final dt = now.timestamp - drag.from.timestamp;
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

  /// With the magnet on, a point within a few pixels of the candle's open,
  /// high, low or close lands exactly on it, at the candle's own time.
  Coordinates _snapped(Coordinates c, Size size) {
    if (!magnet || _candles.isEmpty) return c;
    final interval = _interval.inMilliseconds;
    final index = _candles.indexWhere((k) => k.timestamp + interval > c.timestamp);
    if (index == -1 || _candles[index].timestamp > c.timestamp) return c;
    final candle = _candles[index];
    final projection = projectionFor(size);
    final y = projection.yForPrice(c.price);
    double? best;
    var bestDistance = 10.0;
    for (final level in [candle.open, candle.high, candle.low, candle.close]) {
      final distance = (projection.yForPrice(level) - y).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = level;
      }
    }
    if (best == null) return c;
    return Coordinates(timestamp: candle.timestamp, price: best);
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

    var timeAxisReset = false;
    if (interval != _interval || viewConfig != _viewConfig) {
      _interval = interval;
      _viewConfig = viewConfig;
      _timeAxisEngine.reset(interval: interval, viewConfig: viewConfig);
      timeAxisReset = true;
    }

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

    if (timeAxisReset || resetKeyChanged || candlesChanged) {
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
    final layout = layoutFor(size);
    _eventOrigin = _getEventOrigin(event.localPosition, size, layout);
    _draggedHandle = _eventOrigin == EventOrigin.handle ? layout.handleAt(event.localPosition) : null;
    if (_eventOrigin == EventOrigin.chart) {
      if (_drawingPointerDown(event.localPosition, size)) {
        _eventOrigin = EventOrigin.other;
        return;
      }
      final pos = _getEventPosition(event.localPosition, size);
      onPointerDownInChart(pos, priceAxis, timeAxis, isMobile);
    } else {
      onPointerDownOutsideChart();
    }
    setCrosshairPosition(null);
  }

  void onPointerMove(
    PointerMoveEvent event,
    Size size, {
    required bool Function(Coordinates delta, Coordinates coord, PriceAxis priceAxis) onDragUpdate,
  }) {
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
    _priceAxisEngine.recompute(candles: _candles, timeAxis: timeAxis, priceMargin: _viewConfig.priceMargin);
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

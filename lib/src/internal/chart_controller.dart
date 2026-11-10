import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../models/axis.dart';
import '../models/coordinates.dart';
import 'chart_drawing_input.dart';
import 'chart_layout.dart';
import 'event_origin.dart';

/// Owns a single chart's view interaction: routes the pointer and gestures
/// to pan, zoom (wheel + pinch), the crosshair and the drawings.
///
/// Selection/dragging of chart objects (lines, orders) is delegated to the
/// host via the callbacks passed into [onPointerDown]/[onPointerMove] — this
/// controller never knows what a "line" or "order" is. Plain [ChangeNotifier]
/// on purpose: this state is local to one [TradingChart] instance, so there's
/// no need for an app-wide state management dependency.
class ChartController extends ChartDrawingInput {
  ChartController({
    required super.interval,
    required super.viewConfig,
    required super.candles,
    required super.viewResetKey,
    required super.formatPrice,
    required super.labelStyle,
    required super.indicators,
    required super.colors,
  });

  EventOrigin _eventOrigin = EventOrigin.other;
  int? _draggedHandle;
  double? _lastHorizontalScale;

  /// The pointer that is down — the first finger, a second one being a
  /// pinch — where it went down and whether it has moved past the slop
  /// since: a finger lifted without moving is a tap.
  int? _pointer;
  Offset? _downPosition;
  EventOrigin _downOrigin = EventOrigin.other;
  bool _dragged = false;

  /// Under a finger the crosshair is a mode: a tap on nothing shows it
  /// there, swipes anywhere then move it by as much from where it is, and
  /// a tap anywhere hides it. A mouse hovers instead.
  bool _crosshairPinned = false;
  bool _movingCrosshair = false;

  bool _movingCursor = false;

  /// Whether the crosshair is shown at all; off, a finger's tap on nothing
  /// does nothing and its swipes pan. The cursor still aims a tool.
  bool get crosshair => _crosshair;
  bool _crosshair = true;
  set crosshair(bool value) {
    if (value == _crosshair) return;
    _crosshair = value;
    if (!value && _crosshairPinned) {
      _crosshairPinned = false;
      setCrosshairPosition(null);
    }
  }

  /// The tool changed hands, mid-build: the half-placed points go, the
  /// cursor starts over, and on a phone the crosshair is put away for it.
  /// Touches neither the selection nor the listeners.
  void toolChanged() {
    resetPlacement();
    if (aiming && _crosshairPinned) {
      _crosshairPinned = false;
      crosshairPosition = null;
    }
  }

  /// A finger's tap: aiming, places the tool's point under the cursor;
  /// with the crosshair up, hides it, wherever the tap. Otherwise places
  /// the tool's point, selects the drawing under it, drops the selection
  /// if there is one, or on nothing shows the crosshair there.
  void _touchTap(Offset position, Size size) {
    if (aiming) {
      place(activeTool!, placementCursor(size), size);
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
      if (_downOrigin == EventOrigin.chart) place(tool, position, size);
      return;
    }
    if (_downOrigin == EventOrigin.chart) {
      final hit = drawingAt(position, size);
      if (hit != null) {
        if (!hit.selected) onDrawingSelected?.call(hit.id);
        return;
      }
      if (selectedDrawing != null) {
        onDrawingSelected?.call(null);
        return;
      }
    }
    if (!crosshair) return;
    _crosshairPinned = true;
    setCrosshairPosition(position);
  }

  /// Carries the pinned crosshair by [delta], kept within the plot.
  void _moveCrosshairBy(Offset delta, Size size) {
    final current = crosshairPosition;
    if (current == null) return;
    setCrosshairPosition(offsetWithin(current + delta, layoutFor(size).plotRect));
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
    touch = event.kind == PointerDeviceKind.touch;
    _downPosition = position;
    _downOrigin = _eventOrigin;
    _dragged = false;
    if (touch && aiming) {
      // Wherever it lands: a swipe carries the cursor, a tap places.
      _movingCursor = true;
      _eventOrigin = EventOrigin.other;
      return;
    }
    if (touch && _crosshairPinned) {
      // Wherever it lands: a swipe carries the crosshair, a tap hides it.
      _movingCrosshair = true;
      _eventOrigin = EventOrigin.other;
      return;
    }
    if (_eventOrigin == EventOrigin.chart) {
      // A touch grabs only the selected drawing; selecting, placing and
      // the crosshair wait for the lift, so a swipe pans whatever it
      // started on.
      final taken = touch
          ? activeTool == null && grabSelectedDrawing(position, size)
          : drawingPointerDown(position, size);
      if (taken) {
        _eventOrigin = EventOrigin.other;
        return;
      }
      if (activeTool == null) onPointerDownInChart(eventPosition(position, size), priceAxis, timeAxis, isMobile);
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
    if (!touch) {
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
    _movingCrosshair = false;
    _movingCursor = false;
    releaseDrawing();
  }

  void onPointerMove(
    PointerMoveEvent event,
    Size size, {
    required bool Function(Coordinates delta, Coordinates coord, PriceAxis priceAxis) onDragUpdate,
  }) {
    final down = _downPosition;
    if (down != null && (event.localPosition - down).distance > kTouchSlop) _dragged = true;
    if (_movingCursor) {
      moveCursorBy(event.delta, size);
      return;
    }
    if (_movingCrosshair) {
      _moveCrosshairBy(event.delta, size);
      return;
    }
    if (holdingAfterPlace) {
      setCrosshairPosition(event.localPosition);
      return;
    }
    if (_eventOrigin == EventOrigin.handle) {
      _dragHandle(event.delta.dy, size);
      return;
    }
    if (drawingPointerMove(event.localPosition, size)) return;
    final delta = eventDelta(event.delta, size);
    final coord = eventPosition(event.localPosition, size);
    final hasSelected = _eventOrigin == EventOrigin.chart && onDragUpdate(delta, coord, priceAxis);
    if (!hasSelected) {
      final beforeTime = timeAxis;
      final beforePrice = priceAxis;
      final height = layoutFor(size).priceRect.height;
      if (_eventOrigin == EventOrigin.chart || _eventOrigin == EventOrigin.pane) {
        if (_lastHorizontalScale == null) {
          timeAxisEngine.pan(delta.timestamp);
          if (_eventOrigin == EventOrigin.chart) {
            priceAxisEngine.panBy(event.delta.dy, height, logScale: viewConfig.logScale);
          }
          // Panning changes which candles are visible, so an anchored price
          // axis needs to refit to them too — it's not just following the
          // manual pan above (which only applies while un-anchored).
          refitPriceAxis();
          requestHistoryIfNeeded();
        }
      } else if (_eventOrigin == EventOrigin.yScale) {
        priceAxisEngine.scaleBy(event.delta.dy, height, logScale: viewConfig.logScale);
      }
      if (timeAxis != beforeTime || priceAxis != beforePrice) {
        margins = computeMargins();
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
      final coordinates = eventPosition(event.localPosition, size);
      final offset = (timeAxis.range * 0.0005 * event.scrollDelta.dy).toInt();
      final time = min(max(coordinates.timestamp, timeAxis.start), timeAxis.end);
      final percent = (time - timeAxis.start) / timeAxis.range;
      final beforeTime = timeAxis;
      final beforePrice = priceAxis;
      timeAxisEngine.scale(offset, percent);
      refitPriceAxis();
      requestHistoryIfNeeded();
      if (timeAxis != beforeTime || priceAxis != beforePrice) {
        margins = computeMargins();
        notifyListeners();
      }
    }
  }

  void onDoubleTap() {
    final beforeTime = timeAxis;
    final beforePrice = priceAxis;
    final wasAnchored = priceAxisEngine.anchored;
    if (_eventOrigin == EventOrigin.xScale) {
      timeAxisEngine.reset(interval: interval, viewConfig: viewConfig);
    }
    priceAxisEngine.anchored = true;
    if (!wasAnchored || _eventOrigin == EventOrigin.xScale) {
      refitPriceAxis();
    }
    if (timeAxis != beforeTime || priceAxis != beforePrice) {
      margins = computeMargins();
      notifyListeners();
    }
  }

  void onScaleStart(ScaleStartDetails details) {
    if (details.pointerCount == 2) {
      _lastHorizontalScale = 1.0;
    }
  }

  void onScaleUpdate(ScaleUpdateDetails details, Size size) {
    if (_lastHorizontalScale != null && details.horizontalScale > 0.05) {
      final timeScaleChange = details.horizontalScale / _lastHorizontalScale!;
      final coordinates = eventPosition(details.localFocalPoint, size);
      final time = min(max(coordinates.timestamp, timeAxis.start), timeAxis.end);
      final timePercent = (time - timeAxis.start) / timeAxis.range;
      final beforeTime = timeAxis;
      final beforePrice = priceAxis;
      timeAxisEngine.scaleMobile(timeScaleChange, timePercent);
      _lastHorizontalScale = details.horizontalScale;
      refitPriceAxis();
      requestHistoryIfNeeded();
      if (timeAxis != beforeTime || priceAxis != beforePrice) {
        margins = computeMargins();
        notifyListeners();
      }
    }
  }

  void onScaleEnd(ScaleEndDetails details) {
    _lastHorizontalScale = null;
  }

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
}

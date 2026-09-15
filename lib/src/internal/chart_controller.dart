import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../models/axis.dart';
import '../models/chart_candle.dart';
import '../models/chart_label_style.dart';
import '../models/chart_margins.dart';
import '../models/chart_view_config.dart';
import '../models/coordinates.dart';
import 'event_origin.dart';
import 'price_axis_engine.dart';
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
  }) : _interval = interval,
       _viewConfig = viewConfig,
       _candles = candles,
       _viewResetKey = viewResetKey,
       _formatPrice = formatPrice,
       _labelStyle = labelStyle,
       _timeAxisEngine = TimeAxisEngine(interval: interval, viewConfig: viewConfig) {
    _priceAxisEngine.recompute(candles: _candles, timeAxis: timeAxis, priceMargin: _viewConfig.priceMargin);
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

  EventOrigin _eventOrigin = EventOrigin.other;
  double? _lastHorizontalScale;

  TimeAxis get timeAxis => _timeAxisEngine.axis;
  PriceAxis get priceAxis => _priceAxisEngine.axis;
  late ChartMargins margins;
  Offset? crosshairPosition;

  static const _candlesEquality = ListEquality<ChartCandle>();

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
  }) {
    _formatPrice = formatPrice;
    final labelStyleChanged = labelStyle != _labelStyle;
    _labelStyle = labelStyle;

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

    if (timeAxisReset || resetKeyChanged || candlesChanged) {
      final beforePrice = priceAxis;
      _priceAxisEngine.recompute(candles: _candles, timeAxis: timeAxis, priceMargin: _viewConfig.priceMargin);
      if (timeAxisReset || priceAxis != beforePrice) {
        margins = _computeMargins();
        notifyListeners();
        return;
      }
    }
    if (labelStyleChanged) {
      margins = _computeMargins();
      notifyListeners();
    }
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
    _eventOrigin = _getEventOrigin(event.localPosition, size);
    if (_eventOrigin == EventOrigin.chart) {
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
    final delta = _getEventDelta(event.delta, size);
    final coord = _getEventPosition(event.localPosition, size);
    final hasSelected = onDragUpdate(delta, coord, priceAxis);
    if (!hasSelected) {
      final beforeTime = timeAxis;
      final beforePrice = priceAxis;
      if (_eventOrigin == EventOrigin.chart) {
        if (_lastHorizontalScale == null) {
          _timeAxisEngine.pan(delta.timestamp);
          _priceAxisEngine.panIfUnAnchored(-1 * delta.price);
          // Panning changes which candles are visible, so an anchored price
          // axis needs to refit to them too — it's not just following the
          // manual pan above (which only applies while un-anchored).
          _refitPriceAxis();
        }
      } else if (_eventOrigin == EventOrigin.yScale) {
        _priceAxisEngine.scale(delta.price);
      }
      if (timeAxis != beforeTime || priceAxis != beforePrice) {
        margins = _computeMargins();
        notifyListeners();
      }
    }
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
      if (timeAxis != beforeTime || priceAxis != beforePrice) {
        margins = _computeMargins();
        notifyListeners();
      }
    }
  }

  /// Whether the visible window still includes now.
  bool get isLive => _timeAxisEngine.isLive;

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

  EventOrigin _getEventOrigin(Offset position, Size size) {
    if (size.width - position.dx < margins.right) {
      return EventOrigin.yScale;
    } else if (size.height - position.dy < margins.bottom) {
      return EventOrigin.xScale;
    } else if (position.dy > margins.top && position.dx > margins.left) {
      return EventOrigin.chart;
    } else {
      return EventOrigin.other;
    }
  }

  Coordinates _getEventPosition(Offset position, Size size) {
    final price =
        priceAxis.start +
        ((size.height - position.dy - margins.bottom) * priceAxis.range / (size.height - margins.top - margins.bottom));
    final int time =
        timeAxis.start +
        ((position.dx - margins.left) * timeAxis.range ~/ (size.width - margins.left - margins.right));
    return Coordinates(timestamp: time, price: price);
  }

  Coordinates _getEventDelta(Offset delta, Size size) {
    final priceDelta = -1 * delta.dy * priceAxis.range / (size.height - margins.top - margins.bottom);
    final int timeDelta = -1 * delta.dx * timeAxis.range ~/ (size.width - margins.left - margins.right);
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

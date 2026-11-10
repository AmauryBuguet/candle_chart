import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

import '../models/axis.dart';
import '../models/chart_candle.dart';
import '../models/chart_colors.dart';
import '../models/chart_indicator.dart';
import '../models/chart_label_style.dart';
import '../models/chart_margins.dart';
import '../models/chart_view_config.dart';
import '../models/coordinates.dart';
import 'candle_diff.dart';
import 'candle_time.dart';
import 'chart_layout.dart';
import 'drawing_geometry.dart';
import 'indicator_compute.dart';
import 'indicator_render.dart';
import 'pane_axis.dart';
import 'price_axis_engine.dart';
import 'price_scale.dart';
import 'time_axis_engine.dart';

/// One chart's view: the inputs fed from the widget, the time and price
/// axes they are shown on, every indicator's series and each pane's height
/// and axis, and the margins the labels take. Updated by [updateInputs] and
/// moved by the view actions; pointer handling lives in [ChartController].
class ChartViewport extends ChangeNotifier {
  ChartViewport({
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
       timeAxisEngine = TimeAxisEngine(interval: interval, viewConfig: viewConfig) {
    priceAxisEngine.recompute(
      candles: _candles,
      timeAxis: timeAxis,
      priceMargin: _viewConfig.priceMargin,
      logScale: _viewConfig.logScale,
    );
    _recomputeIndicators();
    _syncPanes();
    margins = computeMargins();
  }

  @protected
  final TimeAxisEngine timeAxisEngine;
  @protected
  final PriceAxisEngine priceAxisEngine = PriceAxisEngine();

  Duration _interval;
  ChartViewConfig _viewConfig;
  List<ChartCandle> _candles;
  Object _viewResetKey;
  String Function(double price) _formatPrice;
  ChartLabelStyle _labelStyle;
  List<ChartIndicator> _indicators;
  ChartColors _colors;

  @protected
  Duration get interval => _interval;
  @protected
  ChartViewConfig get viewConfig => _viewConfig;
  @protected
  List<ChartCandle> get candles => _candles;
  @protected
  ChartLabelStyle get labelStyle => _labelStyle;
  @protected
  ChartColors get colors => _colors;

  /// Told the timestamp of the oldest candle when the view nears it, once
  /// per oldest candle, so the host can fetch what comes before.
  void Function(int before)? onNeedMoreHistory;
  int? _historyRequestedBefore;

  DrawingProjection projectionFor(Size size) {
    final rect = layoutFor(size).priceRect;
    return DrawingProjection(
      rect: rect,
      xForTime: (t) => rect.left + (t - timeAxis.start) / timeAxis.range * rect.width,
      yForPrice: (p) => yForPrice(p, priceAxis, rect, logScale: _viewConfig.logScale),
      timeForX: (x) => timeAxis.start + ((x - rect.left) / rect.width * timeAxis.range).round(),
      priceForY: (y) => priceForY(y, priceAxis, rect, logScale: _viewConfig.logScale),
      candleTime: (t) => candleTimeOf(t, _candles),
    );
  }

  TimeAxis get timeAxis => timeAxisEngine.axis;
  PriceAxis get priceAxis => priceAxisEngine.axis;
  late ChartMargins margins;
  Offset? crosshairPosition;

  /// The series of every indicator, computed once per candle list.
  final Map<ChartIndicator, IndicatorRun> _runs = {};

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

  IndicatorRender renderOf(ChartIndicator indicator) => _runs[indicator]!.render;

  ChartLayout layoutFor(Size size) => ChartLayout(size: size, margins: margins, paneFractions: paneFractions);

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
      timeAxisEngine.reset(interval: interval, viewConfig: viewConfig);
      timeAxisReset = true;
    } else if (viewConfig != _viewConfig) {
      priceAxisEngine.anchored = true;
      priceAxisReset = true;
    }
    _interval = interval;
    _viewConfig = viewConfig;

    var resetKeyChanged = false;
    if (viewResetKey != _viewResetKey) {
      _viewResetKey = viewResetKey;
      priceAxisEngine.anchored = true;
      resetKeyChanged = true;
    }

    final changedFrom = firstChangedCandle(_candles, candles);
    final candlesChanged = changedFrom != null;
    _candles = candles;

    if (indicatorsChanged) {
      _recomputeIndicators();
      _syncPanes();
    } else if (changedFrom != null) {
      _resumeIndicators(changedFrom);
      _syncPanes();
    }
    if (candlesChanged) requestHistoryIfNeeded();

    if (timeAxisReset || priceAxisReset || resetKeyChanged || candlesChanged) {
      final beforePrice = priceAxis;
      refitPriceAxis();
      if (timeAxisReset || priceAxis != beforePrice || indicatorsChanged) {
        margins = computeMargins();
        notifyListeners();
        return;
      }
    }
    if (labelStyleChanged || indicatorsChanged) {
      margins = computeMargins();
      notifyListeners();
    }
  }

  /// The view is within twenty candles of the oldest one, or past it: ask
  /// for more, unless already asked for this same oldest candle.
  @protected
  void requestHistoryIfNeeded() {
    final callback = onNeedMoreHistory;
    if (callback == null || _candles.isEmpty) return;
    final oldest = _candles.first.timestamp;
    if (timeAxis.start > oldest + 20 * _interval.inMilliseconds) return;
    if (_historyRequestedBefore == oldest) return;
    _historyRequestedBefore = oldest;
    callback(oldest);
  }

  void _recomputeIndicators() {
    _runs
      ..clear()
      ..addEntries([for (final i in _indicators) MapEntry(i, runIndicator(i, _candles, _colors))]);
  }

  /// Carries each indicator on from candle [from], the first that changed.
  void _resumeIndicators(int from) {
    for (final i in _indicators) {
      _runs[i] = _runs[i]?.resume(_candles, from) ?? runIndicator(i, _candles, _colors);
    }
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
      for (final pane in paneIndicators)
        fitPaneAxis(render: _runs[pane]!.render, candles: _candles, timeAxis: timeAxis),
    ];
  }

  void setCrosshairPosition(Offset? position) {
    if (position == crosshairPosition) return;
    crosshairPosition = position;
    notifyListeners();
  }

  /// Whether the visible window still includes now.
  bool get isLive => timeAxisEngine.isLive;

  /// Slides the view by [fraction] of its width, right when positive.
  void panByFraction(double fraction) {
    final beforeTime = timeAxis;
    timeAxisEngine.pan((timeAxis.range * fraction).round());
    refitPriceAxis();
    requestHistoryIfNeeded();
    if (timeAxis != beforeTime) {
      margins = computeMargins();
      notifyListeners();
    }
  }

  /// Zooms the view about its middle, in when [factor] is under one.
  void zoomBy(double factor) {
    final beforeTime = timeAxis;
    timeAxisEngine.scale((timeAxis.range * (factor - 1)).round(), 0.5);
    refitPriceAxis();
    requestHistoryIfNeeded();
    if (timeAxis != beforeTime) {
      margins = computeMargins();
      notifyListeners();
    }
  }

  /// Brings the view back to the live edge, keeping the current zoom.
  void jumpToLive() {
    final beforeTime = timeAxis;
    final beforePrice = priceAxis;
    timeAxisEngine.jumpToLive();
    priceAxisEngine.anchored = true;
    refitPriceAxis();
    if (timeAxis != beforeTime || priceAxis != beforePrice) {
      margins = computeMargins();
      notifyListeners();
    }
  }

  /// Refits the price axis to [_candles] within the current [timeAxis].
  /// No-op while the price axis isn't anchored (the user manually
  /// pan/zoomed it) — matches [PriceAxisEngine.recompute]'s own guard.
  @protected
  void refitPriceAxis() {
    priceAxisEngine.recompute(
      candles: _candles,
      timeAxis: timeAxis,
      priceMargin: _viewConfig.priceMargin,
      logScale: _viewConfig.logScale,
    );
    _refitPaneAxes();
  }

  @protected
  Coordinates eventPosition(Offset position, Size size) {
    final rect = layoutFor(size).priceRect;
    final price = priceForY(position.dy, priceAxis, rect, logScale: _viewConfig.logScale);
    final int time = timeAxis.start + ((position.dx - rect.left) * timeAxis.range ~/ rect.width);
    return Coordinates(timestamp: time, price: price);
  }

  /// The price delta is what a linear axis would read; under a log scale a
  /// host dragging its own objects should use the transform's mapping.
  @protected
  Coordinates eventDelta(Offset delta, Size size) {
    final rect = layoutFor(size).priceRect;
    final priceDelta = -1 * delta.dy * priceAxis.range / rect.height;
    final int timeDelta = -1 * delta.dx * timeAxis.range ~/ rect.width;
    return Coordinates(timestamp: timeDelta, price: priceDelta);
  }

  @protected
  ChartMargins computeMargins() {
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

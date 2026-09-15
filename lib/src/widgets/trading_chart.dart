import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';

import '../internal/chart_controller.dart';
import '../models/axis.dart';
import '../models/chart_candle.dart';
import '../models/chart_line.dart';
import '../models/chart_order_line.dart';
import '../models/chart_position.dart';
import '../models/chart_style.dart';
import '../models/chart_transform.dart';
import '../models/chart_view_config.dart';
import '../models/coordinates.dart';
import '../painter/chart_painter.dart';

/// A handle on a mounted [TradingChart]: publishes its live price/time to
/// pixel [transform] so a host can draw its own layer on top of the chart,
/// and drives the view back to the live edge.
///
/// Notifies its listeners whenever [transform] or [isLive] changes.
class TradingChartController extends ChangeNotifier {
  ChartTransform? _transform;
  bool _isLive = true;
  VoidCallback? _jumpToLive;

  /// The chart's current price/time to pixel mapping, `null` until it has
  /// been laid out once.
  ChartTransform? get transform => _transform;

  /// Whether the visible window still includes now.
  bool get isLive => _isLive;

  /// Brings the view back to the live edge, keeping the current zoom.
  void jumpToLive() => _jumpToLive?.call();

  void _attach(VoidCallback jumpToLive) => _jumpToLive = jumpToLive;

  void _detach() => _jumpToLive = null;

  void _sync(ChartTransform transform, {required bool isLive}) {
    if (transform == _transform && isLive == _isLive) return;
    _transform = transform;
    _isLive = isLive;
    notifyListeners();
  }
}

/// An embeddable candlestick trading chart: pan/zoom/scroll, crosshair,
/// draggable price lines, order overlays and position P&L shading.
///
/// The chart owns no domain data itself — everything it draws is passed in,
/// and interaction with drawn objects (selecting/dragging a line or order)
/// is delegated back to the host via callbacks, so the chart never needs to
/// know what a "line" or "order" actually represents.
class TradingChart extends StatefulWidget {
  const TradingChart({
    super.key,
    required this.candles,
    required this.lines,
    required this.orderLines,
    required this.positions,
    required this.style,
    required this.interval,
    required this.viewConfig,
    required this.viewResetKey,
    required this.formatPrice,
    required this.onPointerDownInChart,
    required this.onPointerDownOutsideChart,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.controller,
    this.onPriceAxisChanged,
  });

  final List<ChartCandle> candles;
  final List<ChartLine> lines;
  final List<ChartOrderLine> orderLines;
  final List<ChartPosition> positions;
  final ChartStyle style;

  /// Duration of a single candle — drives the initial/min/max zoom window.
  final Duration interval;
  final ChartViewConfig viewConfig;

  /// Changing this value re-anchors the price axis to fit the visible
  /// candles again (e.g. pass the selected instrument's symbol).
  final Object viewResetKey;

  /// Formats a price for display in axis/crosshair labels.
  final String Function(double price) formatPrice;

  /// Called on pointer-down inside the chart area; the host should hit-test
  /// [lines]/[orderLines] against [pos] and mark the closest one selected.
  final void Function(Coordinates pos, PriceAxis priceAxis, TimeAxis timeAxis, bool isMobile) onPointerDownInChart;

  /// Called on pointer-down outside the chart area (deselect everything).
  final VoidCallback onPointerDownOutsideChart;

  /// Called on pointer-move; return `true` if a selected line/order consumed
  /// the drag (so the chart doesn't also pan the view).
  final bool Function(Coordinates delta, Coordinates coord, PriceAxis priceAxis) onDragUpdate;

  /// Called on pointer-up — the host may commit a drag here (e.g. send an
  /// edited order).
  final Future<void> Function() onDragEnd;

  /// Optional handle exposing the chart's pixel transform and jump-to-live.
  final TradingChartController? controller;

  /// Called whenever the visible price axis changes (pan/zoom/reset),
  /// including once with its initial value.
  final void Function(PriceAxis axis)? onPriceAxisChanged;

  @override
  State<TradingChart> createState() => _TradingChartState();
}

class _TradingChartState extends State<TradingChart> {
  late final ChartController _controller;
  PriceAxis? _lastReportedPriceAxis;

  @override
  void initState() {
    super.initState();
    _controller = ChartController(
      interval: widget.interval,
      viewConfig: widget.viewConfig,
      candles: widget.candles,
      viewResetKey: widget.viewResetKey,
      formatPrice: widget.formatPrice,
      labelStyle: widget.style.labelStyle,
    )..addListener(_handleControllerChanged);
    widget.controller?._attach(_controller.jumpToLive);
    _reportPriceAxisIfChanged();
  }

  @override
  void didUpdateWidget(covariant TradingChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(_controller.jumpToLive);
    }
    _controller.updateInputs(
      interval: widget.interval,
      viewConfig: widget.viewConfig,
      candles: widget.candles,
      viewResetKey: widget.viewResetKey,
      formatPrice: widget.formatPrice,
      labelStyle: widget.style.labelStyle,
    );
    _reportPriceAxisIfChanged();
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    setState(() {});
    _reportPriceAxisIfChanged();
  }

  void _reportPriceAxisIfChanged() {
    final axis = _controller.priceAxis;
    if (axis == _lastReportedPriceAxis) return;
    _lastReportedPriceAxis = axis;
    // Deferred: the host's callback may write to its own state management
    // (e.g. a Riverpod provider), which forbids synchronous writes during a
    // build/lifecycle method — this can be called from initState/
    // didUpdateWidget as well as from gesture handlers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPriceAxisChanged?.call(axis);
    });
  }

  /// Deferred for the same reason as [_reportPriceAxisIfChanged]: this runs
  /// during build, and the host's listeners will usually write to their own
  /// state.
  void _syncController(Size size) {
    final controller = widget.controller;
    if (controller == null) return;
    final transform = ChartTransform(
      size: size,
      margins: _controller.margins,
      priceAxis: _controller.priceAxis,
      timeAxis: _controller.timeAxis,
    );
    final isLive = _controller.isLive;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller._sync(transform, isLive: isLive);
    });
  }

  /// A pointer that is already down is dragging something — the chart itself,
  /// or a host layer above it — so it is not hovering, and re-arming the
  /// crosshair under it would flash it mid-drag.
  void _handleHover(PointerEvent event) {
    if (event.down) return;
    _controller.setCrosshairPosition(event.localPosition);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        _syncController(c.biggest);
        final isMobile = getValueForScreenType<bool>(context: context, mobile: true, desktop: false);
        return SizedBox.expand(
          child: MouseRegion(
            onEnter: _handleHover,
            onHover: _handleHover,
            onExit: (_) => _controller.setCrosshairPosition(null),
            child: Listener(
              onPointerDown: (event) => _controller.onPointerDown(
                event,
                c.biggest,
                isMobile,
                onPointerDownInChart: widget.onPointerDownInChart,
                onPointerDownOutsideChart: widget.onPointerDownOutsideChart,
              ),
              onPointerMove: (event) => _controller.onPointerMove(event, c.biggest, onDragUpdate: widget.onDragUpdate),
              onPointerUp: (event) async {
                if (!isMobile) {
                  _controller.setCrosshairPosition(event.localPosition);
                }
                await widget.onDragEnd();
              },
              onPointerSignal: (event) => _controller.onPointerSignal(event, c.biggest),
              child: GestureDetector(
                onDoubleTap: _controller.onDoubleTap,
                onScaleUpdate: (details) => _controller.onScaleUpdate(details, c.biggest),
                onScaleStart: _controller.onScaleStart,
                onScaleEnd: _controller.onScaleEnd,
                child: CustomPaint(
                  painter: ChartPainter(
                    candles: widget.candles,
                    lines: widget.lines,
                    orderLines: widget.orderLines,
                    margins: _controller.margins,
                    priceAxis: _controller.priceAxis,
                    timeAxis: _controller.timeAxis,
                    crosshairPosition: isMobile ? null : _controller.crosshairPosition,
                    positions: widget.candles.isNotEmpty ? widget.positions : const [],
                    style: widget.style,
                    formatPrice: widget.formatPrice,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

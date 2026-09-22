import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../internal/chart_controller.dart';
import '../models/axis.dart';
import '../models/chart_candle.dart';
import '../models/chart_drawing.dart';
import '../models/chart_indicator.dart';
import '../models/chart_line.dart';
import '../models/chart_order_line.dart';
import '../models/chart_pane_transform.dart';
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
/// indicators over the candles and in panes of their own, the user's
/// drawings, draggable price lines, order overlays and position P&L
/// shading.
///
/// The chart owns no domain data itself — everything it draws is passed in,
/// and interaction with drawn objects (selecting/dragging a line or order)
/// is delegated back to the host via callbacks, so the chart never needs to
/// know what a "line" or "order" actually represents. Drawings are the one
/// thing the chart hit-tests and drags itself, since their geometry is its
/// own; the host still owns the list and every change comes back to it.
///
/// A mouse hovers the crosshair and grabs drawings as it clicks. Under a
/// finger the crosshair is a mode, whatever the screen: off, a tap on a
/// drawing selects it, a tap on nothing shows the crosshair there, and a
/// swipe pans — or moves the drawing it starts on, once that one is
/// selected; on, a swipe anywhere moves the crosshair by as much from
/// where it is, and a tap anywhere hides it. A mouse selects a drawing
/// with a click too, and moves it only from the next one.
///
/// A tool is aimed with the mouse, a click placing each point. Below
/// desktop width it is aimed with a cursor instead: it starts in the
/// middle of the price pane, swipes anywhere move it by as much, a tap
/// places the point under it, and it stays for the next point.
///
/// On desktop the chart takes focus on a click and answers the keyboard:
/// Escape or a right click drops a half-placed drawing and the selection
/// and reports through [onDrawingCancelled], Delete or Backspace deletes the
/// selected drawing, the arrow keys pan, plus and minus zoom, Home jumps to
/// live. A web host wanting the right click must keep the browser's context
/// menu off the chart.
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
    this.indicators = const [],
    this.drawings = const [],
    this.activeTool,
    this.magnet = true,
    this.onDrawingCreated,
    this.onDrawingChanged,
    this.onDrawingSelected,
    this.onDrawingDeleted,
    this.onDrawingCancelled,
    this.onNeedMoreHistory,
  });

  final List<ChartCandle> candles;
  final List<ChartLine> lines;
  final List<ChartOrderLine> orderLines;
  final List<ChartPosition> positions;
  final ChartStyle style;

  /// The studies drawn from the candles: overlays over them, pane
  /// indicators in panes under them, in list order. Their series are
  /// computed once per candle list and kept until either changes.
  final List<ChartIndicator> indicators;

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
  final void Function(
    Coordinates pos,
    PriceAxis priceAxis,
    TimeAxis timeAxis,
    bool isMobile,
  )
  onPointerDownInChart;

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

  /// The user's drawings, in the price pane. The one with `selected` set
  /// shows its handles; the chart reports selection and edits back, and the
  /// host replaces entries in this list.
  final List<ChartDrawing> drawings;

  /// The tool in hand: while set, clicks in the price pane — or taps, with
  /// the cursor, below desktop width — place its points, and
  /// [onDrawingCreated] is called with the drawing once the last one is
  /// down. Nothing is selected or panned meanwhile.
  final ChartDrawingTool? activeTool;

  /// Whether a placed or dragged anchor snaps to the open, high, low or
  /// close of the candle under it — the nearest in time, as the crosshair
  /// aligns — when one is within reach in price.
  final bool magnet;

  final void Function(ChartDrawing drawing)? onDrawingCreated;

  /// A drawing moved — an anchor dragged, or the whole thing — as a new
  /// instance with the same id. The host's [onDragEnd] follows the last one.
  final void Function(ChartDrawing drawing)? onDrawingChanged;

  /// A drawing was tapped, or `null` when the tap landed on nothing while
  /// one was selected.
  final void Function(Object? id)? onDrawingSelected;

  /// Delete or Backspace with a drawing selected.
  final void Function(Object id)? onDrawingDeleted;

  /// Escape or a right click: the half-placed drawing and the selection are
  /// gone, and the host may put [activeTool] down.
  final VoidCallback? onDrawingCancelled;

  /// The view is nearing the oldest candle: the host may fetch what comes
  /// before it and pass a longer list. Called once per oldest candle.
  final void Function(int before)? onNeedMoreHistory;

  @override
  State<TradingChart> createState() => _TradingChartState();
}

const _desktopBreakpoint = 950.0;

class _TradingChartState extends State<TradingChart> {
  late final ChartController _controller;
  final FocusNode _focus = FocusNode(debugLabel: 'TradingChart');
  PriceAxis? _lastReportedPriceAxis;

  void _syncDrawingInputs() {
    _controller
      ..drawings = widget.drawings
      ..activeTool = widget.activeTool
      ..magnet = widget.magnet
      ..onDrawingCreated = widget.onDrawingCreated
      ..onDrawingChanged = widget.onDrawingChanged
      ..onDrawingSelected = widget.onDrawingSelected
      ..onDrawingDeleted = widget.onDrawingDeleted
      ..onDrawingCancelled = widget.onDrawingCancelled
      ..onNeedMoreHistory = widget.onNeedMoreHistory;
  }

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
      indicators: widget.indicators,
      colors: widget.style.colors,
    )..addListener(_handleControllerChanged);
    _syncDrawingInputs();
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
      indicators: widget.indicators,
      colors: widget.style.colors,
    );
    _syncDrawingInputs();
    if (widget.activeTool != oldWidget.activeTool) {
      _controller.toolChanged();
      // Escape must drop the tool before the first click gives the chart focus.
      if (widget.activeTool != null) _focus.requestFocus();
    }
    _reportPriceAxisIfChanged();
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.escape): _controller.cancelDrawing,
    const SingleActivator(LogicalKeyboardKey.delete): _controller.deleteSelectedDrawing,
    const SingleActivator(LogicalKeyboardKey.backspace): _controller.deleteSelectedDrawing,
    const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _controller.panByFraction(-0.1),
    const SingleActivator(LogicalKeyboardKey.arrowRight): () => _controller.panByFraction(0.1),
    const SingleActivator(LogicalKeyboardKey.equal): () => _controller.zoomBy(0.8),
    const SingleActivator(LogicalKeyboardKey.add): () => _controller.zoomBy(0.8),
    const SingleActivator(LogicalKeyboardKey.minus): () => _controller.zoomBy(1.25),
    const SingleActivator(LogicalKeyboardKey.numpadSubtract): () => _controller.zoomBy(1.25),
    const SingleActivator(LogicalKeyboardKey.home): _controller.jumpToLive,
  };

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
    final layout = _controller.layoutFor(size);
    final transform = ChartTransform(
      size: size,
      margins: _controller.margins,
      priceAxis: _controller.priceAxis,
      timeAxis: _controller.timeAxis,
      paneSpace: layout.paneSpace,
      panes: [
        for (var i = 0; i < layout.paneRects.length; i++)
          ChartPaneTransform(
            rect: layout.paneRects[i],
            axis: _controller.paneAxes[i],
          ),
      ],
    );
    final isLive = _controller.isLive;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller._sync(transform, isLive: isLive);
    });
  }

  /// A pointer that is already down is dragging something — the chart itself,
  /// or a host layer above it — so it is not hovering, and re-arming the
  /// crosshair under it would flash it mid-drag. A finger never hovers: the
  /// web engine reports one leaving the page as a hover, which would park
  /// the crosshair under it.
  void _handleHover(PointerEvent event) {
    if (event.down || event.kind == PointerDeviceKind.touch) return;
    _controller.setCrosshairPosition(event.localPosition);
  }

  /// Below desktop width a tool is aimed with the cursor, and the host is
  /// told. A desktop OS is judged on the window's width, a phone or tablet
  /// on its shortest side, whichever way it is held. How a pointer behaves
  /// otherwise is the pointer's kind, not the width: a finger taps, a mouse
  /// hovers.
  static bool _isMobile(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = switch (defaultTargetPlatform) {
      TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.linux => size.width,
      _ => size.shortestSide,
    };
    return width < _desktopBreakpoint;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        _syncController(c.biggest);
        final isMobile = _isMobile(context);
        _controller.cursorPlacement = isMobile;
        return CallbackShortcuts(
          bindings: _shortcuts,
          child: Focus(
            focusNode: _focus,
            child: SizedBox.expand(
              child: MouseRegion(
                cursor: _controller.cursorFor(c.biggest),
                onEnter: _handleHover,
                onHover: _handleHover,
                onExit: (event) {
                  if (event.kind != PointerDeviceKind.touch) _controller.setCrosshairPosition(null);
                },
                child: Listener(
                  onPointerDown: (event) {
                    _focus.requestFocus();
                    if (event.buttons == kSecondaryMouseButton) {
                      _controller.cancelDrawing();
                      return;
                    }
                    _controller.onPointerDown(
                      event,
                      c.biggest,
                      isMobile,
                      onPointerDownInChart: widget.onPointerDownInChart,
                      onPointerDownOutsideChart: widget.onPointerDownOutsideChart,
                    );
                  },
                  onPointerMove: (event) =>
                      _controller.onPointerMove(event, c.biggest, onDragUpdate: widget.onDragUpdate),
                  onPointerUp: (event) async {
                    _controller.onPointerUp(event, c.biggest);
                    await widget.onDragEnd();
                  },
                  onPointerCancel: (_) => _controller.onPointerCancel(),
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
                        layout: _controller.layoutFor(c.biggest),
                        priceAxis: _controller.priceAxis,
                        timeAxis: _controller.timeAxis,
                        crosshairPosition: _controller.crosshairFor(c.biggest),
                        crosshairArmed: _controller.activeTool != null,
                        positions: widget.candles.isNotEmpty ? widget.positions : const [],
                        style: widget.style,
                        formatPrice: widget.formatPrice,
                        overlays: [for (final o in _controller.overlays) (o, _controller.renderOf(o))],
                        panes: [for (final p in _controller.paneIndicators) (p, _controller.renderOf(p))],
                        paneAxes: _controller.paneAxes,
                        drawings: widget.drawings,
                        placing: _controller.placingFor(c.biggest),
                      ),
                    ),
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

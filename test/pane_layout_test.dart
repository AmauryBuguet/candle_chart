import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart/src/internal/chart_controller.dart';
import 'package:trading_chart/src/internal/chart_layout.dart';
import 'package:trading_chart/trading_chart.dart';

List<ChartCandle> _candles() {
  final start = DateTime.now().millisecondsSinceEpoch - 40 * 60000;
  return [
    for (var i = 0; i < 40; i++)
      ChartCandle(
        timestamp: start + i * 60000,
        endTimestamp: start + (i + 1) * 60000,
        open: 100,
        high: 101,
        low: 99,
        close: 100,
        volume: 1,
      ),
  ];
}

ChartController _controller(List<ChartIndicator> indicators) => ChartController(
  interval: const Duration(minutes: 1),
  viewConfig: const ChartViewConfig(),
  candles: _candles(),
  viewResetKey: 'BTC',
  formatPrice: (price) => price.toStringAsFixed(1),
  labelStyle: const ChartLabelStyle(),
  indicators: indicators,
  colors: const ChartColors(),
);

void main() {
  test('panes stack under the price pane, a handle above each', () {
    final layout = ChartLayout(
      size: const Size(400, 300),
      margins: const ChartMargins(left: 0, top: 10, right: 50, bottom: 20),
      paneFractions: const [0.2, 0.1],
    );
    // Plot height 270: panes of 54 and 27 plus two handles of 6.
    expect(layout.paneRects[1], const Rect.fromLTRB(0, 253, 350, 280));
    expect(layout.handleRects[1], const Rect.fromLTRB(0, 247, 350, 253));
    expect(layout.paneRects[0], const Rect.fromLTRB(0, 193, 350, 247));
    expect(layout.handleRects[0], const Rect.fromLTRB(0, 187, 350, 193));
    expect(layout.priceRect, const Rect.fromLTRB(0, 10, 350, 187));
    expect(layout.paneSpace, 93);
    expect(layout.paneAt(const Offset(10, 260)), 1);
    expect(layout.handleAt(const Offset(10, 190)), 0);
    expect(layout.paneAt(const Offset(10, 100)), isNull);
  });

  test('pane fractions are kept sane, the price pane never squeezed out', () {
    expect(clampPaneFractions([0.01, 0.9]), [0.05, 0.6]);
    final many = clampPaneFractions([0.3, 0.3, 0.3]);
    expect(many.reduce((a, b) => a + b), closeTo(0.8, 1e-9));
  });

  test('a pane keeps its height across edits to the list and a new one takes its own', () {
    final controller = _controller([const ChartVolume(height: 0.15), const ChartRsi(color: Colors.blue, height: 0.3)]);
    expect(controller.paneFractions, [0.15, 0.3]);

    controller.updateInputs(
      interval: const Duration(minutes: 1),
      viewConfig: const ChartViewConfig(),
      candles: _candles(),
      viewResetKey: 'BTC',
      formatPrice: (price) => price.toStringAsFixed(1),
      labelStyle: const ChartLabelStyle(),
      indicators: [
        const ChartRsi(color: Colors.blue, height: 0.3),
        const ChartVolume(height: 0.1),
      ],
      colors: const ChartColors(),
    );
    // Same volume indicator? No — its height changed, so it is a new one.
    expect(controller.paneFractions, [0.3, 0.1]);
    expect(controller.paneAxes, hasLength(2));
  });

  test('dragging the handle above a pane grows it and shrinks the price pane', () {
    final controller = _controller([const ChartVolume(height: 0.2)]);
    const size = Size(400, 300);
    final handle = controller.layoutFor(size).handleRects[0].center;

    controller.onPointerDown(
      PointerDownEvent(position: handle, kind: PointerDeviceKind.mouse),
      size,
      false,
      onPointerDownInChart: (_, _, _, _) => fail('a handle is not the chart'),
      onPointerDownOutsideChart: () {},
    );
    controller.onPointerMove(
      PointerMoveEvent(position: handle - const Offset(0, 27), delta: const Offset(0, -27)),
      size,
      onDragUpdate: (_, _, _) => false,
    );
    // The plot is 300 minus the gutters; 27 px up on a ~270 px plot is a tenth.
    expect(controller.paneFractions[0], closeTo(0.3, 0.01));
    expect(controller.layoutFor(size).priceRect.bottom, lessThan(handle.dy));
  });
}

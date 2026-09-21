An independent, embeddable candlestick trading chart widget for Flutter.

## Features

- Candlestick rendering with grid and axis labels.
- Indicators, passed as a list of value objects and computed once per candle
  list: over the candles (`ChartSma`, `ChartEma`, `ChartWma`, `ChartVwap`,
  `ChartBollinger`, `ChartIchimoku`, `ChartSuperTrend`, `ChartVolumeProfile`)
  or in a pane of their own under the price pane, on their own value axis
  (`ChartVolume`, `ChartRsi`, `ChartMacd`, `ChartStochastic`). Panes stack in
  list order with a drag handle above each; `ChartTransform.panes` tells a
  host where they are.
- Drawings (`ChartDrawing`): trend line, ray, extended line, horizontal
  line and ray, vertical line, rectangle, parallel channel, Fibonacci
  retracement and extension, text and measure, anchored in time and price. The chart
  hit-tests, selects and drags them, snaps anchors to OHLC with the magnet,
  places new ones with `activeTool`, and reports every change back through
  callbacks; `toJson`/`fromJson` carry them wherever the host keeps them.
- Candles or a line through the closes (`ChartStyle.chartType`); a linear or
  logarithmic price axis (`ChartViewConfig.logScale`).
- Pan (drag), wheel zoom, pinch zoom, double-tap to reset/anchor the price
  axis, and on desktop the keyboard: arrows pan, plus and minus zoom, Home
  jumps to live, Escape and Delete act on drawings.
- `onNeedMoreHistory`: told the oldest candle's timestamp when the view
  nears it, once, so the host can fetch what comes before.
- Optional crosshair with time/price labels on hover.
- Draggable horizontal price lines (`ChartLine`) and order overlays
  (`ChartOrderLine`, drawn from their placement time with a "ghost" line back
  to their original price while being edited).
- Closed/open position P&L shading (`ChartPosition`).
- Configurable empty space to the right of the latest candle
  (`ChartViewConfig.rightMargin`) and a jump-back-to-live control.
- A published price/time to pixel transform (`ChartTransform`), so hosts can
  draw their own layer on top of the chart.

The chart owns no domain data: everything it draws is passed in as plain,
exchange-agnostic models, and interaction with drawn objects (selecting or
dragging a line/order) is delegated back to the host via callbacks — the
chart never needs to know what a "line" or "order" represents in the host
app's domain.

## Usage

```dart
TradingChart(
  candles: candles,           // List<ChartCandle>
  lines: lines,                // List<ChartLine>
  orderLines: orderLines,      // List<ChartOrderLine>
  positions: positions,        // List<ChartPosition>
  style: const ChartStyle(),
  indicators: const [ChartEma(period: 20, color: Colors.amber), ChartRsi(color: Colors.purple)],
  interval: const Duration(minutes: 15),
  viewConfig: const ChartViewConfig(),
  controller: chartController,  // TradingChartController: transform + jumpToLive
  viewResetKey: selectedSymbol,
  formatPrice: (price) => price.toStringAsFixed(2),
  onPointerDownInChart: (pos, priceAxis, timeAxis, isMobile) {
    // hit-test `lines`/`orderLines` against `pos` and mark the closest one selected
  },
  onPointerDownOutsideChart: () {
    // deselect everything
  },
  onDragUpdate: (delta, coord, priceAxis) {
    // move the selected line/order to `coord.price`, return true if something moved
    return false;
  },
  onDragEnd: () async {
    // commit a drag (e.g. send an edited order)
  },
)
```

### Drawing your own layer

Pass a `TradingChartController` and stack your own widget over the chart. The
controller notifies on every view change and exposes `transform`
(`yForPrice`/`priceForY`/`xForTime`/`timeForX` plus the `plotArea` rect), and
`isLive`/`jumpToLive()` for a jump-back-to-now button.

## Additional information

Part of the Graphite workspace, shared by its trading and charting apps. `movable` on `ChartLine`/
`ChartOrderLine` defaults to `true` and is currently unused by the chart's
own gesture handling — it's a hook for hosts implementing a "lock this
line/order" feature; enforcing it is the host's responsibility when
hit-testing in `onPointerDownInChart`/`onDragUpdate`.

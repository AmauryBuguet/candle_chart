An independent, embeddable candlestick trading chart widget for Flutter.

## Features

- Candlestick rendering with grid, axis labels and an optional Visible-Range
  Volume Profile (VPVR).
- Pan (drag), wheel zoom, pinch zoom, and double-tap to reset/anchor the
  price axis.
- Optional crosshair with time/price labels on hover.
- Draggable horizontal price lines (`ChartLine`) and order overlays
  (`ChartOrderLine`, drawn from their placement time with a "ghost" line back
  to their original price while being edited).
- Closed/open position P&L shading (`ChartPosition`).

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
  settings: const ChartSettings(),
  interval: const Duration(minutes: 15),
  viewConfig: const ChartViewConfig(),
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

## Additional information

Part of the [traderaft](../traderaft) app. `movable` on `ChartLine`/
`ChartOrderLine` defaults to `true` and is currently unused by the chart's
own gesture handling — it's a hook for hosts implementing a "lock this
line/order" feature; enforcing it is the host's responsibility when
hit-testing in `onPointerDownInChart`/`onDragUpdate`.

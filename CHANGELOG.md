## 0.4.4

* Compiles to WebAssembly: the mobile/desktop split no longer goes through `responsive_builder`, whose `dart:io` probe throws under wasm. A desktop browser is now judged on the window's width rather than its shortest side.

## 0.4.3

* A right click drops a half-placed drawing, keeping the tool and the selection.

## 0.4.2

* Swapping `activeTool` while a drawing is being placed no longer deselects through `onDrawingSelected` during the host's build; only the half-placed points are dropped.

## 0.4.1

* `ChartViewConfig.copyWith`.

## 0.4.0

* Drawings: `TradingChart.drawings` takes `ChartDrawing`s — trend line, ray, extended line, horizontal line and ray, vertical line, rectangle, parallel channel, Fibonacci retracement, text, measure — anchored in time and price. The chart hit-tests them, shows the selected one's handles, drags an anchor or the whole drawing, snaps to the candle's open, high, low or close with `magnet`, and places new ones with `activeTool`; `onDrawingCreated`, `onDrawingChanged`, `onDrawingSelected` and `onDrawingDeleted` hand every change back. `toJson`/`fromJson` serialise them. A new drawing takes `ChartColors.drawing`.
* `ChartStyle.chartType`: candles, or a line through the closes in `ChartColors.line`.
* `ChartViewConfig.logScale`: a logarithmic price axis, with ticks at 1, 2 and 5 of each decade. `ChartTransform.yForPrice`/`priceForY` follow it; a host doing its own axis maths must check `ChartTransform.logScale`.
* `onNeedMoreHistory`: called with the oldest candle's timestamp when the view comes within twenty candles of it, once per oldest candle.
* Keyboard, on desktop, once the chart has been clicked: arrows pan a tenth of the view, plus and minus zoom, Home jumps to live, Escape drops a half-placed drawing and the selection, Delete and Backspace delete the selected drawing.

## 0.3.0

* Indicators are a list of value objects on the chart, `TradingChart.indicators`, in place of `ChartStyle.vpvr`, `volume`, `emas` and `bollinger`, which are gone. Each is computed once per candle list and cached against the instance.
* Overlays over the candles: `ChartSma`, `ChartEma`, `ChartWma`, `ChartVwap` (reset each UTC day), `ChartBollinger`, `ChartIchimoku` (cloud drawn ahead, lagging span behind), `ChartSuperTrend`, `ChartVolumeProfile` (the former VPVR, with its own colours).
* Panes: `ChartVolume`, `ChartRsi`, `ChartMacd` and `ChartStochastic` each take a pane of their own under the price pane, with a value axis fitted to what is visible or fixed for a bounded oscillator, guide levels, a hairline handle above it that drags to resize, and the grid and crosshair running through. `ChartTransform.panes` and `paneSpace` say where they are; `plotArea` stays the price pane.
* Volume is a pane, no longer bars along the bottom of the price pane.

## 0.2.1

* The price axis is sized from its ticks as they are painted, in `ChartLabelStyle.textStyle` with `labelMargin` either side, instead of in the default font: a smaller label style no longer leaves a blank strip to the right of the prices.

## 0.2.0

* `ChartStyle.volume`: each candle's volume as a bar along the bottom of the chart, in its candle's colour, scaled to the busiest visible candle.
* `ChartStyle.emas`: exponential moving averages of the closes (`ChartEma(period, color)`), drawn over the candles and under lines, orders and positions.
* The grid is drawn at 1px rather than 0.1px, which anti-aliased it out of sight, and `ChartStyle.grid` now hides the vertical lines as well as the horizontal ones.
* `ChartStyle.bollinger`: Bollinger Bands (`ChartBollinger(period, deviation, color)`), the channel faintly filled, drawn at the same level.

## 0.1.4

* A position's shading starts at its entry, never before it: the candle the entry falls in is picked up from the entry itself rather than from its open, so an entry drawn on a candle's body no longer shades the half of that candle that came first.

## 0.1.3

* The position surface follows candle opens as well as closes: it runs across each candle from its open to its close, then steps at the slot boundary to the next open. Samples sit at the edges of a candle's slot, since a body is drawn centred on its own timestamp — using `endTimestamp` put a candle's close over the next candle.

## 0.1.2

* `ChartStyle.filledUpCandles` / `filledDownCandles`: paint a candle body solid instead of hollow. Both default to false, so nothing changes unless asked for.

## 0.1.1

* The crosshair no longer flashes under a pointer that is dragging — a host layer's drag over the chart used to re-arm it on every mouse enter.

## 0.1.0

* `ChartViewConfig.rightMargin`: configurable empty space kept to the right of the latest candle.
* `TradingChartController`: publishes the chart's `ChartTransform` (price/time to pixel mapping) and drives `jumpToLive()` / `isLive`.
* `ChartMargins` and `ChartTransform` are now part of the public API.

## 0.0.1

* Initial extraction from the traderaft app's chart panel: candlestick rendering, pan/zoom/scroll, crosshair, draggable lines/orders, position P&L shading.

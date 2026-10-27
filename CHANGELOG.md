## 0.12.0

* Renamed from `trading_chart` to `candle_chart` and published under the MIT licence; import `package:candle_chart/candle_chart.dart`.
* An example app under `example/`, and screenshots in the README.

## 0.11.1

* The time axis reads the time through `package:clock`, so a host's tests can say what time it is.

## 0.11.0

* `ChartDrawing.hiddenIn` replaces `hidden`: the host's views a drawing is kept out of, carried by `toJson`; `TradingChart.view` names the one shown, and the drawings hidden in it are neither drawn nor hit.

## 0.10.1

* A drawing's point shows on the candle that holds its time, so one set on a finer interval no longer slides onto the next candle.

## 0.10.0

* `ChartStyle.studyOpacity`: the price pane's overlay indicators, volume profile and drawings at a lower opacity, so a host's own objects stand out; a drawing being placed stays opaque.

## 0.9.0

* `ChartAtr`: Wilder's average true range, in a pane of its own.
* `ChartPeriodLevels`: the current day's, week's or month's levels — the previous period's high and low, the current one's open, high and low — from the period's start to the last candle, each labelled at its right end where the label fits; the host may pass both periods' ranges (`ChartPeriodRange`) when the candles do not reach back that far. `ChartLevelPeriod` gives a period's start and its neighbours', in UTC.
* `ChartSessions`: the Asian, London and New York sessions as boxes spanning each one's high and low, on candles of an hour or less, daylight saving included.
* `ChartFibLevel`: each level of a Fibonacci retracement or extension can be hidden or given its own colour (`levels`, defaulting to `defaultLevels`, carried by `toJson`); `ChartColors.fibLevels` sets the colour a new drawing's level of each ratio is created in.
* The colours of `ChartIchimoku`, `ChartSuperTrend`, `ChartMacd`, `ChartStochastic`, `ChartPeriodLevels` and `ChartSessions` are nullable: a line, a side or a session with none is not drawn.
* `TradingChart.styleDrawing`: the host styles a drawing the tool is placing, on its preview and once created, with its own defaults.
* `ChartPolyline` and `ChartDrawingTool.polyline`: segments through any number of points, placed until one lands on the last or Enter is pressed (`ChartDrawingTool.open`).

## 0.8.0

* A rectangle has a handle in the middle of each side, which moves that side alone.
* A Fibonacci retracement has a handle in the middle of its 0 line, which moves it in price only.
* A selected horizontal line keeps its handle at the time in the middle of the price pane when it was selected, and a vertical line at the price there; dragging either moves it along its own axis only.
* The mouse cursor over a handle shows the way it drags.

## 0.7.0

* `TradingChart.magnetReach` sets how far in pixels the magnet reaches; it was a fixed 30.
* `ChartStyle.crosshair` off also stops a finger's tap from pinning a crosshair, so its swipes pan; the cursor that aims a tool is still drawn.

## 0.6.1

* The crosshair's price and time labels use the chart's label style, like the axis labels, instead of the default font.

## 0.6.0

* The log scale is back: `ChartViewConfig.logScale` and `ChartTransform.logScale` return, with the axis fit, the ticks at 1, 2 and 5 of each decade, the price-axis pan and zoom by ratio, and a drawing dragged by ratio rather than by amount.

## 0.5.2

* The trend-based Fibonacci extension drops the ratios between 0 and 1: `fibExtensionLevels` is 0, 1, 1.618, 2.618, 3.618, 4.236.
* The armed crosshair is drawn at 0.8 rather than 1.2, closer to the resting one.

## 0.5.1

* Shift held while a point is aimed after another — the tool's next point, or a dragged anchor — locks it to that point's time or price, whichever is nearer on screen (`ChartController.axisLock`, read off the keyboard by the widget). The lock beats the magnet.
* The formatter's page width is 120, as the code was already laid out.

## 0.5.0

* The log scale is gone: `ChartViewConfig.logScale` and `ChartTransform.logScale` are removed, the price axis is linear only.
* The mouse cursor over a drawing: a pointing hand over one a click would select, `resizeUpDown` over a selected horizontal line or ray, `resizeLeftRight` over a selected vertical line, `move` over any other selected drawing or its anchors, kept while it is dragged.

## 0.4.8

* Trend-based Fibonacci extension (`ChartFibExtension`, `ChartDrawingTool.fibExtension`), on three points: the move from the first to the second, projected from the third at the ratios 0 to 4.236 (`fibExtensionLevels`, `fibExtensionPrice`). The two legs are drawn, the levels run from the third point to the right edge, each labelled with its ratio and price.

## 0.4.7

* A parallel channel's third point sets only its width: the second line is the first carried straight across, so the two are the sides of a rectangle, and the third handle sits in the middle of the second line.
* A rectangle has a handle on each of its four corners; dragging a derived corner moves the two points it is made of (`movedAnchor`).
* Fibonacci retracement levels run from 1 on the first point's price to 0 on the second's (`fibPrice`).
* With a tool in hand the crosshair is drawn in `ChartColors.cursor`, thicker, on every platform — no longer only the phone's cursor (`ChartPainter.crosshairArmed`).
* Picking a tool up gives the chart keyboard focus, so Escape drops it before the first point is placed, as a right click already did.
* The magnet reaches 30 pixels in price instead of 20.
* A placed or dragged point lands on the candle grid in time, as the crosshair aligns, with or without the magnet; a dragged drawing moves by whole intervals.
* A mouse held down after placing a point keeps aiming the next one: the crosshair and the placement preview follow it as they do a hover, and nothing pans. The next point is still placed by the next click.

## 0.4.6

* A drawing is selected before it moves: a click or tap on it selects it, and only the selected one is dragged, so a swipe starting on an unselected drawing pans. A drawing is hit on its strokes only, no longer inside a filled area, within 8 pixels for a mouse and 16 for a finger (`DrawingHitTolerance`).
* Under a finger — by the pointer's kind, whatever the window's width — the crosshair is a mode. Off, a tap on nothing shows the crosshair there. On, a swipe anywhere moves the crosshair by as much from where it is, and a tap anywhere hides it. On the web a finger's lift, which the engine reports as a hover, no longer parks the crosshair under it.
* Below desktop width a tool is aimed with a cursor: it starts in the middle of the price pane, swipes anywhere move it by as much, a tap places the point under it and it stays for the next one; the placement preview follows it. The crosshair is put away for it. The cursor is drawn in `ChartColors.cursor`, thicker than the crosshair. A tap on nothing with a drawing selected only drops the selection.
* Under a log scale the price axis fits the visible candles with `priceMargin` of their log range above and below, instead of a linear margin that left most of the pane empty under a wide range. Switching `logScale` (or `priceMargin`) refits the prices under the same time window instead of resetting the view to the live edge.

## 0.4.5

* The magnet snaps to the candle nearest in time, as the crosshair aligns, rather than the one whose slot the pointer is in, and reaches 20 pixels in price instead of 10. With a tool in hand the crosshair is drawn where the next point would land, so the pull shows before the click.
* A right click does what Escape does — drops the half-placed drawing and the selection — and both report through `onDrawingCancelled`, so the host can put the tool down.

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

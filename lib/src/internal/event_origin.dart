/// Where a pointer went down: the price pane, an indicator pane, the handle
/// above a pane, one of the two axis gutters, or nowhere the chart cares.
enum EventOrigin { chart, pane, handle, xScale, yScale, other }

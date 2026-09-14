import 'package:equatable/equatable.dart';

/// Constraints on the chart's visible time window, expressed in candles.
class ChartViewConfig extends Equatable {
  /// How many candles are visible on first load.
  final int startCandles;

  /// The minimum number of candles the view can be zoomed in to.
  final int minCandles;

  /// The maximum number of candles the view can be zoomed out to.
  final int maxCandles;

  /// Empty space kept to the right of the latest candle, as a fraction of
  /// the visible time window. Room for lines and labels ahead of price.
  final double rightMargin;

  /// Extra vertical breathing room above/below the visible candles' high/low,
  /// as a fraction of their range (e.g. `0.1` = 10%).
  final double priceMargin;

  const ChartViewConfig({
    this.startCandles = 100,
    this.minCandles = 4,
    this.maxCandles = 1000,
    this.rightMargin = 0.25,
    this.priceMargin = 0.1,
  });

  @override
  List<Object> get props => [startCandles, minCandles, maxCandles, rightMargin, priceMargin];
}

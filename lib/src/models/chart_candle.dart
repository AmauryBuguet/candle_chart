import 'package:equatable/equatable.dart';

/// A single OHLCV candlestick, independent of any specific exchange/data source.
class ChartCandle extends Equatable {
  /// Start timestamp of the candle, in milliseconds since epoch.
  final int timestamp;

  /// End timestamp of the candle, in milliseconds since epoch.
  final int endTimestamp;

  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const ChartCandle({
    required this.timestamp,
    required this.endTimestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  @override
  List<Object> get props => [timestamp, endTimestamp, open, high, low, close, volume];
}

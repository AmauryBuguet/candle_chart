import 'dart:ui';

import 'package:equatable/equatable.dart';

/// An exponential moving average of the closes, drawn as a line over the
/// candles.
class ChartEma extends Equatable {
  const ChartEma({required this.period, required this.color}) : assert(period > 0);

  /// How many candles the average spans.
  final int period;

  final Color color;

  @override
  List<Object> get props => [period, color];
}

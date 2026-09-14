import 'dart:ui';

import 'package:equatable/equatable.dart';

/// Bollinger Bands: a simple moving average of the closes with a band on
/// each side at [deviation] standard deviations.
class ChartBollinger extends Equatable {
  const ChartBollinger({required this.period, required this.deviation, required this.color})
    : assert(period > 1),
      assert(deviation > 0);

  /// How many candles the average and its deviation span.
  final int period;

  /// How many standard deviations each band sits from the average.
  final double deviation;

  final Color color;

  @override
  List<Object> get props => [period, deviation, color];
}

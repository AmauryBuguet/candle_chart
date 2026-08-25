import 'package:equatable/equatable.dart';

/// A generic axis representation with a start and end value.
abstract class Axis<T extends num> extends Equatable {
  /// Creates a new [Axis] instance.
  const Axis({required this.start, required this.end}) : assert(start < end);

  /// The starting value of the axis.
  final T start;

  /// The ending value of the axis.
  final T end;

  /// Helper function to get the axis range
  T get range => ((end - start) as T);

  /// Returns a copy of this axis with optional new values.
  /// Subclasses must override this method.
  Axis<T> copyWith({T? start, T? end});
}

/// A numeric price axis.
class PriceAxis extends Axis<double> {
  /// Creates a new [PriceAxis] instance.
  const PriceAxis({super.start = 0, super.end = 100});

  @override
  PriceAxis copyWith({double? start, double? end}) {
    return PriceAxis(start: start ?? this.start, end: end ?? this.end);
  }

  @override
  List<Object> get props => [start, end];
}

/// A date/time axis.
class TimeAxis extends Axis<int> {
  /// Creates a new [TimeAxis] instance.
  const TimeAxis({super.start = 1231006505000, super.end = 1231092905000});

  @override
  TimeAxis copyWith({int? start, int? end}) {
    return TimeAxis(start: start ?? this.start, end: end ?? this.end);
  }

  @override
  List<Object> get props => [start, end];
}

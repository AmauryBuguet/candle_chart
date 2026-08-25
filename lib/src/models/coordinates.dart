import 'package:equatable/equatable.dart';

/// Holds a point in chart coordinates, defined by a timestamp and a price value.
class Coordinates extends Equatable {
  /// Creates a [Coordinates] object with [timestamp] and [price].
  const Coordinates({required this.timestamp, required this.price});

  /// The time value of the coordinate.
  final int timestamp;

  /// The price value of the coordinate.
  final double price;

  @override
  List<Object> get props => [timestamp, price];
}

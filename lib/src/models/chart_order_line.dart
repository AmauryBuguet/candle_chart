import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// A resting order drawn on the chart from its placement time onward,
/// with an optional "ghost" line back to its original price while being
/// dragged to a new one.
class ChartOrderLine extends Equatable {
  /// Identifies this order to the host app; echoed back in drag callbacks.
  final Object id;

  /// Placement time of the order, in milliseconds since epoch.
  final int timestamp;

  /// The order's resting price (drawn as a faint "ghost" line while [newPrice] differs).
  final double originalPrice;

  /// The order's current (possibly being-dragged) price.
  final double newPrice;

  final Color color;
  final bool selected;

  /// Whether this order can currently be selected/dragged.
  ///
  /// Defaults to `true`. Reserved for a future "lock" feature — the chart
  /// does not yet gate selection on this flag itself; hosts that want to
  /// prevent dragging should filter it out before hit-testing.
  final bool movable;

  const ChartOrderLine({
    required this.id,
    required this.timestamp,
    required this.originalPrice,
    required this.newPrice,
    required this.color,
    this.selected = false,
    this.movable = true,
  });

  @override
  List<Object?> get props => [id, timestamp, originalPrice, newPrice, color, selected, movable];
}

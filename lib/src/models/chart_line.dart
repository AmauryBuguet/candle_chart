import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// A horizontal, draggable price line drawn across the full chart width
/// (e.g. a draft entry/stop-loss/take-profit line).
class ChartLine extends Equatable {
  /// Identifies this line to the host app; echoed back in drag callbacks.
  final Object id;

  final double price;
  final Color color;
  final bool selected;

  /// Whether this line can currently be selected/dragged.
  ///
  /// Defaults to `true`. Reserved for a future "lock" feature — the chart
  /// does not yet gate selection on this flag itself; hosts that want to
  /// prevent dragging should filter it out before hit-testing.
  final bool movable;

  const ChartLine({
    required this.id,
    required this.price,
    required this.color,
    this.selected = false,
    this.movable = true,
  });

  @override
  List<Object?> get props => [id, price, color, selected, movable];
}

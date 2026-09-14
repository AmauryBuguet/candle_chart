import 'package:equatable/equatable.dart';

/// Defines the margins around the chart area.
class ChartMargins extends Equatable {
  /// Left margin in logical pixels.
  final double left;

  /// Top margin in logical pixels.
  final double top;

  /// Right margin in logical pixels.
  final double right;

  /// Bottom margin in logical pixels.
  final double bottom;

  /// Creates a new instance of [ChartMargins].
  const ChartMargins({required this.left, required this.top, required this.right, required this.bottom});

  @override
  List<Object> get props => [left, top, right, bottom];
}

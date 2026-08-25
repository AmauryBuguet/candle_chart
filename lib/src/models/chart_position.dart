import 'package:equatable/equatable.dart';

import 'coordinates.dart';

enum ChartPositionSide { long, short }

/// A filled position overlay, shaded green/red between its entry and (if
/// closed) exit points depending on running P&L.
class ChartPosition extends Equatable {
  final ChartPositionSide side;
  final Coordinates entry;

  /// Null while the position is still open — the chart then draws it out to
  /// the last available candle.
  final Coordinates? exit;

  const ChartPosition({
    required this.side,
    required this.entry,
    this.exit,
  });

  @override
  List<Object?> get props => [side, entry, exit];
}

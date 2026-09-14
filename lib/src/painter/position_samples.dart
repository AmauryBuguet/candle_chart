import '../models/chart_candle.dart';

/// Half a candle's own interval. A body is drawn centred on the candle's
/// timestamp, so the candle occupies the slot from half an interval before it
/// to half an interval after.
int _half(ChartCandle candle) => (candle.endTimestamp - candle.timestamp) ~/ 2;

/// When a candle's open is drawn: the left edge of its slot.
int openTime(ChartCandle candle) => candle.timestamp - _half(candle);

/// When a candle's close is drawn: the right edge of its slot, which is where
/// the next candle's open begins.
int closeTime(ChartCandle candle) => candle.timestamp + _half(candle);

/// The prices a position's shaded edge is traced through, in time order:
/// open, close, open, close, one pair per candle.
///
/// Tracking closes alone smooths the shading over every gap between one
/// candle and the next. Tracking both means the edge runs across each candle
/// from its open to its close, then steps at the boundary to the next open —
/// the shape the candles themselves make.
///
/// The run always ends on the exit, whether that is where the position closed
/// or the live price of the candle still forming. It never starts before the
/// entry: a position drawn back to the open of the candle it was entered in
/// would shade time it did not exist for.
List<(int, double)> positionSamples({
  required List<ChartCandle> candles,
  required int entryTimestamp,
  required int exitTimestamp,
  required double exitPrice,
}) {
  final List<(int, double)> samples = [];

  for (final candle in candles) {
    final int opens = openTime(candle);
    final int closes = closeTime(candle);
    if (closes <= entryTimestamp) continue;
    if (opens >= exitTimestamp) break;

    if (opens > entryTimestamp) samples.add((opens, candle.open));
    if (closes < exitTimestamp) samples.add((closes, candle.close));
  }

  samples.add((exitTimestamp, exitPrice));
  return samples;
}

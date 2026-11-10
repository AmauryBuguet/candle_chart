import '../models/chart_candle.dart';

const _second = 1000;
const _minute = 60 * _second;
const _hour = 60 * _minute;
const _day = 24 * _hour;

/// The time left before the forming candle — the last of [candles] — closes
/// at [now], in milliseconds since epoch. `00:00` while the next candle is
/// late, and nothing once it is a whole candle late, the feed then stale.
String? candleCountdown(List<ChartCandle> candles, int now) {
  if (candles.isEmpty) return null;
  final last = candles.last;
  final close = last.endTimestamp + 1;
  final remaining = close - now;
  if (remaining <= last.timestamp - close) return null;
  return formatCountdown(remaining < 0 ? 0 : remaining);
}

/// [ms] as a countdown in its two largest units — `mm:ss` under an hour,
/// hours and minutes under a day, days and hours beyond — rounded up to the
/// second so it reads zero only once the time is up.
String formatCountdown(int ms) {
  final total = (ms + _second - 1) ~/ _second * _second;
  String two(int value) => value.toString().padLeft(2, '0');
  if (total >= _day) return '${total ~/ _day}d ${total % _day ~/ _hour}h';
  final minutes = two(total % _hour ~/ _minute);
  if (total >= _hour) return '${total ~/ _hour}h ${minutes}m';
  return '$minutes:${two(total % _minute ~/ _second)}';
}

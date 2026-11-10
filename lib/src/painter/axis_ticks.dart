import 'dart:math';

import '../internal/timesteps.dart';
import '../models/axis.dart';

/// Ceiling on the decimal places kept when cleaning up generated tick values,
/// to avoid floating-point noise (e.g. 0.1 + 0.2) — unrelated to any price
/// formatting/precision rule, which is entirely up to [ChartPainter.formatPrice].
const int _maxTickCleanupDecimals = 8;

/// Generates rounded price ticks based on chart height.
List<double> nicePriceTicks(double start, double end, double chartHeight, double minSpacing) {
  final range = end - start;
  final approxTicks = (chartHeight / minSpacing).floor().clamp(2, 100);
  final rawStep = range / approxTicks;
  final step = _niceStep(rawStep);
  final firstStepIndex = (start / step).ceil();
  final lastStepIndex = (end / step).floor();
  final ticks = <double>[];
  for (int i = firstStepIndex; i <= lastStepIndex; i++) {
    final rawTick = i * step;
    ticks.add(_cleanFloat(rawTick));
  }
  return ticks;
}

/// Ticks at 1, 2 and 5 of each decade the axis spans, thinned to the
/// decades alone when they would crowd, and the linear ticks when the
/// range is too narrow to hold two of them.
List<double> logPriceTicks(double start, double end, double chartHeight, double minSpacing) {
  if (start <= 0) return nicePriceTicks(start, end, chartHeight, minSpacing);
  final ticks = <double>[];
  final lowDecade = (log(start) / ln10).floor();
  final highDecade = (log(end) / ln10).ceil();
  for (var k = lowDecade; k <= highDecade; k++) {
    for (final m in const [1, 2, 5]) {
      final tick = m * pow(10, k).toDouble();
      if (tick >= start && tick <= end) ticks.add(_cleanFloat(tick));
    }
  }
  final maxTicks = (chartHeight / minSpacing).floor().clamp(2, 100);
  if (ticks.length > maxTicks) {
    ticks.removeWhere((t) => (log(t) / ln10) % 1 != 0);
  }
  if (ticks.length < 2) return nicePriceTicks(start, end, chartHeight, minSpacing);
  return ticks;
}

double _cleanFloat(double value) {
  return double.parse(value.toStringAsFixed(_maxTickCleanupDecimals));
}

/// Rounds raw step to a human-friendly value.
double _niceStep(double raw) {
  final exp = (log(raw) / ln10).floor();
  final base = raw / pow(10, exp);
  final rounded = base < 1.5
      ? 1
      : base < 3
      ? 2
      : base < 7
      ? 5
      : 10;
  return rounded * pow(10, exp).toDouble();
}

/// Generates rounded time ticks and the format string to use.
(List<DateTime>, String) niceTimeTicks(TimeAxis timeAxis, double chartWidth, double minSpacing) {
  final rangeMs = timeAxis.range;
  final approxTicks = (chartWidth / minSpacing).floor().clamp(2, 50);
  final rawStep = rangeMs ~/ approxTicks;

  final timestep = TimeSteps.values.firstWhere(
    (e) => rawStep < e.duration.inMilliseconds,
    orElse: () => TimeSteps.values.last,
  );

  final ticks = <DateTime>[];
  DateTime date = DateTime.fromMillisecondsSinceEpoch(timeAxis.start);
  if (timestep.duration.inDays < 2) {
    final offset = date.timeZoneOffset;
    final firstTickMs =
        ((timeAxis.start + offset.inMilliseconds) / timestep.duration.inMilliseconds).ceil() *
            timestep.duration.inMilliseconds -
        offset.inMilliseconds;
    for (int ms = firstTickMs; ms <= timeAxis.end; ms += timestep.duration.inMilliseconds) {
      ticks.add(DateTime.fromMillisecondsSinceEpoch(ms));
    }
  } else {
    final endDate = DateTime.fromMillisecondsSinceEpoch(timeAxis.end);
    if (timestep.duration.inDays < 25) {
      date = date.add(const Duration(days: 1));
      int day = ((date.day - 1) / timestep.duration.inDays).ceil() * timestep.duration.inDays + 1;
      DateTime currDate = DateTime(date.year, date.month, day);
      while (true) {
        if (currDate.month != date.month) {
          currDate = DateTime(currDate.year, currDate.month);
        }
        if (currDate.isBefore(endDate)) {
          if (ticks.isNotEmpty && currDate.difference(ticks.last) < timestep.duration) {
            ticks.removeLast();
          }
          ticks.add(currDate);
        } else {
          break;
        }
        date = currDate;
        currDate = currDate.add(timestep.duration);
      }
    } else if (timestep.duration.inDays < 365) {
      date = DateTime(date.year, date.month + 1);
      int nbMonth = timestep.duration.inDays ~/ 30;
      int month = ((date.month - 1) / nbMonth).ceil() * nbMonth + 1;
      DateTime currDate = DateTime(date.year, month);
      while (true) {
        if (currDate.year != date.year) {
          currDate = DateTime(currDate.year);
        }
        if (currDate.isBefore(endDate)) {
          ticks.add(currDate);
        } else {
          break;
        }
        date = currDate;
        currDate = DateTime(currDate.year, currDate.month + nbMonth);
      }
    } else {
      date = DateTime(date.year + 1);
      int nbYears = timestep.duration.inDays ~/ 365;
      int year = (date.year / nbYears).ceil() * nbYears;
      DateTime currDate = DateTime(year);
      while (true) {
        if (currDate.isBefore(endDate)) {
          ticks.add(currDate);
        } else {
          break;
        }
        date = currDate;
        currDate = DateTime(currDate.year + nbYears);
      }
    }
  }
  return (ticks, timestep.format);
}

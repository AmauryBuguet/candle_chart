import 'package:clock/clock.dart';
import '../models/axis.dart';
import '../models/chart_view_config.dart';

/// Pure time-axis state and pan/zoom math. No framework dependency.
class TimeAxisEngine {
  TimeAxisEngine({required Duration interval, required ChartViewConfig viewConfig}) {
    reset(interval: interval, viewConfig: viewConfig);
  }

  late TimeAxis axis;
  late int _minRange;
  late int _maxRange;
  late double _rightMargin;

  /// Whether the current window still shows the live edge of the market.
  bool get isLive => axis.end >= clock.now().millisecondsSinceEpoch;

  void reset({required Duration interval, required ChartViewConfig viewConfig}) {
    _minRange = interval.inMilliseconds * viewConfig.minCandles;
    _maxRange = interval.inMilliseconds * viewConfig.maxCandles;
    _rightMargin = viewConfig.rightMargin;
    _anchorToNow(interval.inMilliseconds * viewConfig.startCandles);
  }

  /// Re-centres the window on now, keeping the current zoom level.
  void jumpToLive() => _anchorToNow(axis.range);

  void _anchorToNow(int range) {
    final end = clock.now().millisecondsSinceEpoch + (range * _rightMargin).round();
    axis = TimeAxis(start: end - range, end: end);
  }

  void pan(int value) {
    axis = axis.copyWith(start: axis.start + value, end: axis.end + value);
  }

  void scale(int offset, double percent) {
    final start = axis.start - (offset * percent).toInt();
    final end = axis.end + (offset * (1 - percent)).toInt();
    if (start < end && (end - start) > _minRange && (end - start) < _maxRange) {
      axis = axis.copyWith(start: start, end: end);
    }
  }

  void scaleMobile(double scale, double percent) {
    final start = axis.start - (axis.range * percent * (1 - scale) * 1.2).toInt();
    final end = axis.end + (axis.range * (1 - percent) * (1 - scale) * 1.2).toInt();
    if (start < end && (end - start) > _minRange && (end - start) < _maxRange) {
      axis = axis.copyWith(start: start, end: end);
    }
  }
}

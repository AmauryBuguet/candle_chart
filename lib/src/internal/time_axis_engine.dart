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

  void reset({required Duration interval, required ChartViewConfig viewConfig}) {
    _minRange = interval.inMilliseconds * viewConfig.minCandles;
    _maxRange = interval.inMilliseconds * viewConfig.maxCandles;
    axis = TimeAxis(
      start: DateTime.now().subtract(interval * viewConfig.startCandles * 0.75).millisecondsSinceEpoch,
      end: DateTime.now().add(interval * viewConfig.startCandles * 0.25).millisecondsSinceEpoch,
    );
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

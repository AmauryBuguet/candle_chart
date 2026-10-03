import 'dart:math';

import 'package:flutter/painting.dart';

import '../internal/indicator_render.dart';
import '../models/chart_candle.dart';

/// Draws an indicator's series into one pane: boxes and fills first, then
/// bars, then lines, then labels, all clipped to the pane.
class SeriesPainter {
  SeriesPainter({
    required this.canvas,
    required this.rect,
    required this.candles,
    required this.firstIndex,
    required this.endIndex,
    required this.intervalMs,
    required this.xForTime,
    required this.yForValue,
    required this.textStyle,
  });

  final Canvas canvas;
  final Rect rect;
  final List<ChartCandle> candles;

  /// The visible candles, plus one either side so lines run to the edges.
  final int firstIndex;
  final int endIndex;
  final int intervalMs;
  final double Function(int timestamp) xForTime;
  final double Function(double value) yForValue;

  /// The labels' style, in each series' or box's colour.
  final TextStyle textStyle;

  void draw(IndicatorRender render) {
    if (firstIndex == -1 || endIndex == -1 || candles.isEmpty) return;
    canvas.save();
    canvas.clipRect(rect);
    render.boxes.forEach(_drawBox);
    for (final band in render.bands) {
      _drawBand(render.series[band.first], render.series[band.second], band);
    }
    for (final series in render.series) {
      if (series.kind == SeriesKind.histogram) _drawHistogram(series);
    }
    for (final series in render.series) {
      if (series.kind == SeriesKind.line) _drawLine(series);
      if (series.kind == SeriesKind.step) _drawSteps(series);
    }
    canvas.restore();
  }

  /// The x of the value indexed on candle [i], drawn [offset] candles along.
  double _x(int i, int offset) => xForTime(candles[i].timestamp + offset * intervalMs);

  (int, int) _range(int offset) => (
    max(0, firstIndex - 1 - offset.abs()),
    min(candles.length, endIndex + 1 + offset.abs()),
  );

  void _drawLine(IndicatorSeries series) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = series.width
      ..strokeJoin = StrokeJoin.round
      ..color = series.color;
    final path = Path();
    var started = false;
    final (from, to) = _range(series.offset);
    for (var i = from; i < to; i++) {
      final value = series.values[i];
      if (value == null) {
        started = false;
        continue;
      }
      final x = _x(i, series.offset);
      final y = yForValue(value);
      if (started) {
        path.lineTo(x, y);
      } else {
        path.moveTo(x, y);
        started = true;
      }
    }
    canvas.drawPath(path, paint);
  }

  /// One segment per run of equal values, its label over its right end —
  /// or the pane's, for a run going past it — when the run is wide enough
  /// on screen to hold it.
  void _drawSteps(IndicatorSeries series) {
    final runs = <({double left, double right, double y})>[];
    double? previous;
    final (from, to) = _range(series.offset);
    for (var i = from; i < to; i++) {
      final value = series.values[i];
      if (value != null) {
        final right = _x(i, series.offset + 1);
        if (value == previous) {
          runs.last = (left: runs.last.left, right: right, y: runs.last.y);
        } else {
          runs.add((left: _x(i, series.offset), right: right, y: yForValue(value)));
        }
      }
      previous = value;
    }
    final path = Path();
    for (final run in runs) {
      path
        ..moveTo(run.left, run.y)
        ..lineTo(run.right, run.y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = series.width
        ..color = series.color,
    );
    if (series.label.isEmpty) return;
    final label = _label(series.label, series.color);
    for (final run in runs) {
      final left = max(run.left, rect.left);
      final right = min(run.right, rect.right);
      if (right - left < label.width + 2 * _labelInset) continue;
      label.paint(canvas, Offset(right - label.width - _labelInset, run.y - label.height));
    }
  }

  /// A box, its label inside its top corner when it is tall enough, over it
  /// otherwise, and only when it is wide enough on screen.
  void _drawBox(IndicatorBox box) {
    final r = Rect.fromLTRB(xForTime(box.start), yForValue(box.high), xForTime(box.end), yForValue(box.low));
    if (r.right < rect.left || r.left > rect.right) return;
    canvas.drawRect(r, Paint()..color = box.color.withAlpha(22));
    canvas.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = box.color.withAlpha(120),
    );
    if (box.label.isEmpty) return;
    final label = _label(box.label, box.color);
    final left = max(r.left, rect.left);
    if (min(r.right, rect.right) - left < label.width + 2 * _labelInset) return;
    final inside = r.height >= label.height + 2 * _labelInset;
    label.paint(canvas, Offset(left + _labelInset, inside ? r.top + _labelInset : r.top - label.height));
  }

  static const _labelInset = 4.0;

  TextPainter _label(String text, Color color) => TextPainter(
    text: TextSpan(
      text: text,
      style: textStyle.copyWith(color: color),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  void _drawHistogram(IndicatorSeries series) {
    final halfWidth = (xForTime(intervalMs) - xForTime(0)) * 0.35;
    final zero = yForValue(0);
    final paint = Paint()..style = PaintingStyle.fill;
    final (from, to) = _range(series.offset);
    for (var i = from; i < to; i++) {
      final value = series.values[i];
      if (value == null) continue;
      final color = series.barColors == null ? series.color : series.barColors![i];
      if (color == null) continue;
      paint.color = color;
      final x = _x(i, series.offset);
      final y = yForValue(value);
      final top = min(y, zero);
      final bottom = max(y, zero);
      canvas.drawRect(Rect.fromLTRB(x - halfWidth, top, x + halfWidth, max(bottom, top + 1)), paint);
    }
  }

  /// One polygon per run where the first series stays on the same side of
  /// the second, split at each crossing so the colour changes exactly there.
  void _drawBand(IndicatorSeries first, IndicatorSeries second, IndicatorBand band) {
    final (from, to) = _range(max(first.offset.abs(), second.offset.abs()));
    final tops = <Offset>[];
    final bottoms = <Offset>[];
    bool? above;

    void flush() {
      final side = above;
      if (tops.length < 2 || side == null) return;
      final path = Path()..moveTo(tops.first.dx, tops.first.dy);
      for (final point in tops.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      for (final point in bottoms.reversed) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = side ? band.above : band.below);
      tops.clear();
      bottoms.clear();
    }

    Offset? previousA;
    Offset? previousB;
    for (var i = from; i < to; i++) {
      final a = first.values[i];
      final b = second.values[i];
      if (a == null || b == null) {
        flush();
        above = null;
        previousA = null;
        previousB = null;
        continue;
      }
      final pointA = Offset(_x(i, first.offset), yForValue(a));
      final pointB = Offset(_x(i, second.offset), yForValue(b));
      final nowAbove = a >= b;
      if (above != null && nowAbove != above && previousA != null && previousB != null) {
        // Where the two lines cross between the last point and this one.
        final gapBefore = previousA.dy - previousB.dy;
        final gapNow = pointA.dy - pointB.dy;
        final t = gapBefore / (gapBefore - gapNow);
        final crossing = Offset.lerp(previousA, pointA, t)!;
        tops.add(crossing);
        bottoms.add(crossing);
        flush();
        tops.add(crossing);
        bottoms.add(crossing);
      }
      above = nowAbove;
      tops.add(pointA);
      bottoms.add(pointB);
      previousA = pointA;
      previousB = pointB;
    }
    flush();
  }
}

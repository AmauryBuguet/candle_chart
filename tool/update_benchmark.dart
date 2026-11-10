// Times one live tick through ChartController.updateInputs, and each
// indicator's full computation. Run with `flutter test tool/update_benchmark.dart`.
import 'dart:math';
import 'dart:ui';

import 'package:candle_chart/candle_chart.dart';
import 'package:candle_chart/src/internal/chart_controller.dart';
import 'package:candle_chart/src/internal/indicator_compute.dart';
import 'package:flutter_test/flutter_test.dart';

const _minute = 60000;
const _color = Color(0xFF2196F3);

const _indicators = <ChartIndicator>[
  ChartSma(period: 20, color: _color),
  ChartEma(period: 50, color: _color),
  ChartBollinger(period: 20, deviation: 2, color: _color),
  ChartIchimoku(
    conversionColor: _color,
    baseColor: _color,
    spanAColor: _color,
    spanBColor: _color,
    laggingColor: _color,
  ),
  ChartVwap(color: _color),
  ChartVolumeProfile(color: _color, pocColor: _color),
  ChartVolume(),
  ChartRsi(color: _color),
  ChartMacd(macdColor: _color, signalColor: _color, upColor: _color, downColor: _color),
];

List<ChartCandle> _series(int count, int start) {
  final random = Random(7);
  var price = 100.0;
  return [
    for (var i = 0; i < count; i++) _candle(start + i * _minute, price += random.nextDouble() - 0.5, random),
  ];
}

ChartCandle _candle(int timestamp, double close, Random random) => ChartCandle(
  timestamp: timestamp,
  endTimestamp: timestamp + _minute,
  open: close - 0.2,
  high: close + random.nextDouble(),
  low: close - random.nextDouble(),
  close: close,
  volume: random.nextDouble() * 10,
);

/// The host maps its own candles anew on every build: equal values, new instances.
List<ChartCandle> _fresh(List<ChartCandle> candles) => [
  for (final c in candles)
    ChartCandle(
      timestamp: c.timestamp,
      endTimestamp: c.endTimestamp,
      open: c.open,
      high: c.high,
      low: c.low,
      close: c.close,
      volume: c.volume,
    ),
];

ChartController _controller(List<ChartCandle> candles) => ChartController(
  interval: const Duration(minutes: 1),
  viewConfig: const ChartViewConfig(),
  candles: candles,
  viewResetKey: 'BTC',
  formatPrice: (price) => price.toStringAsFixed(2),
  labelStyle: const ChartLabelStyle(),
  indicators: _indicators,
  colors: const ChartColors(),
);

/// Microseconds per update, feeding [inputs] in turn to a controller built on [first].
double _timeUpdates(List<ChartCandle> first, List<List<ChartCandle>> inputs) {
  final controller = _controller(first);
  final watch = Stopwatch()..start();
  for (final candles in inputs) {
    _update(controller, candles);
  }
  return watch.elapsedMicroseconds / inputs.length;
}

/// Microseconds per call of [body], after a warm-up.
double _time(int runs, void Function() body) {
  for (var i = 0; i < 20; i++) {
    body();
  }
  final watch = Stopwatch()..start();
  for (var i = 0; i < runs; i++) {
    body();
  }
  return watch.elapsedMicroseconds / runs;
}

void _update(ChartController controller, List<ChartCandle> candles) => controller.updateInputs(
  interval: const Duration(minutes: 1),
  viewConfig: const ChartViewConfig(),
  candles: candles,
  viewResetKey: 'BTC',
  formatPrice: (price) => price.toStringAsFixed(2),
  labelStyle: const ChartLabelStyle(),
  indicators: _indicators,
  colors: const ChartColors(),
);

void main() {
  const ticks = 100;
  for (final count in [1500, 6000]) {
    test('$count candles', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ _minute * _minute;
      final base = _series(count, now - (count - 1) * _minute);
      final random = Random(3);
      final lines = <String>['--- $count candles (µs per call) ---'];

      for (final indicator in _indicators) {
        final us = _time(100, () => renderIndicator(indicator, base, const ChartColors()));
        lines.add('render ${indicator.runtimeType}: ${us.toStringAsFixed(1)}');
      }

      final ticked1 = [...base.sublist(0, count - 1), _candle(base.last.timestamp, base.last.close + 1, random)];
      for (final indicator in _indicators) {
        final run = runIndicator(indicator, base, const ChartColors());
        final us = _time(
          100,
          () => run.resume(ticked1, count - 1) ?? runIndicator(indicator, ticked1, const ChartColors()),
        );
        lines.add('resume ${indicator.runtimeType}: ${us.toStringAsFixed(1)}');
      }

      // Warms the update path up before any timing.
      _timeUpdates(base, [for (var i = 0; i < 20; i++) _fresh(base)]);

      String report(double us) => us.toStringAsFixed(1);
      lines.add('tick, same list: ${report(_timeUpdates(base, [for (var i = 0; i < ticks; i++) base]))}');
      lines.add(
        'tick, equal values, fresh instances: ${report(_timeUpdates(base, [for (var i = 0; i < ticks; i++) _fresh(base)]))}',
      );

      final ticked = <List<ChartCandle>>[];
      var current = base;
      for (var i = 0; i < ticks; i++) {
        final last = current.last;
        current = _fresh([...current.sublist(0, count - 1), _candle(last.timestamp, last.close + 0.01, random)]);
        ticked.add(current);
      }
      lines.add('tick, last candle changed (fresh instances): ${report(_timeUpdates(base, ticked))}');

      final appended = <List<ChartCandle>>[];
      var grown = base;
      for (var i = 0; i < ticks; i++) {
        final last = grown.last;
        grown = _fresh([...grown, _candle(last.timestamp + _minute, last.close, random)]);
        appended.add(grown);
      }
      lines.add('tick, one candle appended (fresh instances): ${report(_timeUpdates(base, appended))}');

      final older = _series(1500, base.first.timestamp - 1500 * _minute);
      final prepended = [..._fresh(older), ..._fresh(base)];
      lines.add('page prepended: ${report(_timeUpdates(base, [prepended]))}');

      // ignore: avoid_print
      print(lines.join('\n'));
    });
  }
}

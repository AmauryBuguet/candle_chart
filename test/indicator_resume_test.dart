import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:candle_chart/src/internal/chart_controller.dart';
import 'package:candle_chart/src/internal/indicator_compute.dart';
import 'package:candle_chart/src/internal/indicator_render.dart';
import 'package:candle_chart/candle_chart.dart';

const _minute = 60000;

ChartCandle _candle(int index, Random random, double price) => ChartCandle(
  timestamp: index * _minute,
  endTimestamp: (index + 1) * _minute,
  open: price - random.nextDouble(),
  high: price + random.nextDouble() * 2,
  low: price - random.nextDouble() * 2,
  close: price,
  volume: random.nextDouble() * 10,
);

List<ChartCandle> _candles(int count, {int seed = 1}) {
  final random = Random(seed);
  var price = 100.0;
  return [for (var i = 0; i < count; i++) _candle(i, random, price += random.nextDouble() * 2 - 1)];
}

/// [candles] with the last one moved to [close].
List<ChartCandle> _ticked(List<ChartCandle> candles, double close) => [
  ...candles.take(candles.length - 1),
  _candle(candles.length - 1, Random(close.round()), close),
];

/// [candles] with one more after them.
List<ChartCandle> _appended(List<ChartCandle> candles, double close) => [
  ...candles,
  _candle(candles.length, Random(close.round()), close),
];

void _expectSameRender(IndicatorRender actual, IndicatorRender expected) {
  expect(actual.series.length, expected.series.length);
  for (var k = 0; k < expected.series.length; k++) {
    final a = actual.series[k];
    final e = expected.series[k];
    expect(a.values, e.values, reason: 'series $k values');
    expect(a.barColors, e.barColors, reason: 'series $k bar colours');
    expect((a.color, a.width, a.kind, a.offset, a.label), (e.color, e.width, e.kind, e.offset, e.label));
  }
  expect(actual.bands.length, expected.bands.length);
  for (var k = 0; k < expected.bands.length; k++) {
    final a = actual.bands[k];
    final e = expected.bands[k];
    expect((a.first, a.second, a.above, a.below), (e.first, e.second, e.above, e.below));
  }
  expect(actual.boxes, isEmpty);
  expect(expected.boxes, isEmpty);
  expect(actual.levels, expected.levels);
  expect(actual.fixedRange, expected.fixedRange);
}

const _resumable = <ChartIndicator>[
  ChartBollinger(period: 20, deviation: 2, color: Colors.blue),
  ChartIchimoku(
    conversionColor: Colors.blue,
    baseColor: Colors.red,
    spanAColor: Colors.green,
    spanBColor: Colors.orange,
    laggingColor: Colors.purple,
  ),
];

/// Computed in full on every change, and checked against a fresh controller.
const _others = <ChartIndicator>[
  ChartSma(period: 20, color: Colors.blue),
  ChartEma(period: 12, color: Colors.blue),
  ChartVwap(color: Colors.blue),
  ChartVolume(),
  ChartRsi(color: Colors.blue),
  ChartMacd(macdColor: Colors.blue, signalColor: Colors.orange, upColor: Colors.green, downColor: Colors.red),
];

void main() {
  for (final indicator in _resumable) {
    group('${indicator.runtimeType} carried on matches a full recompute', () {
      const colors = ChartColors();
      final base = _candles(200);
      IndicatorRun run(List<ChartCandle> candles) => runIndicator(indicator, candles, colors);
      void expectResumed(List<ChartCandle> before, List<ChartCandle> after, int from) {
        final resumed = run(before).resume(after, from);
        expect(resumed, isNotNull);
        _expectSameRender(resumed!.render, renderIndicator(indicator, after, colors));
      }

      test('the last candle changed', () => expectResumed(base, _ticked(base, 140), 199));
      test('a candle appended', () => expectResumed(base, _appended(base, 90), 200));
      test('the last candle changed and another appended', () {
        expectResumed(base, _appended(_ticked(base, 130), 70), 199);
      });
      test('from the first candle, as on a page prepended', () {
        expectResumed(base, [..._candles(50, seed: 9), ...base], 0);
      });
      test('from within the warm-up', () => expectResumed(base, [...base.take(5), ..._candles(195, seed: 4)], 5));
      test('fewer candles than the warm-up, then enough', () {
        final short = base.take(8).toList();
        expectResumed(short, base, 8);
        expectResumed(base, short, 8);
      });
      test('tick after tick, each carried on from the last', () {
        var candles = base;
        var current = run(candles);
        final random = Random(5);
        for (var i = 0; i < 30; i++) {
          final appending = i % 4 == 3;
          final from = appending ? candles.length : candles.length - 1;
          final close = 100 + random.nextDouble() * 20;
          candles = appending ? _appended(candles, close) : _ticked(candles, close);
          final next = current.resume(candles, from);
          expect(next, isNotNull);
          current = next!;
        }
        _expectSameRender(current.render, renderIndicator(indicator, candles, colors));
      });
    });
  }

  test('a live tick leaves the controller as a fresh one on the same candles', () {
    for (final indicator in _others) {
      expect(runIndicator(indicator, _candles(30), const ChartColors()).resume(_candles(30), 29), isNull);
    }

    final candles = _candles(300);
    ChartController controller(List<ChartCandle> candles) => ChartController(
      interval: const Duration(minutes: 1),
      viewConfig: const ChartViewConfig(),
      candles: candles,
      viewResetKey: 'BTC',
      formatPrice: (price) => price.toStringAsFixed(1),
      labelStyle: const ChartLabelStyle(),
      indicators: const [..._others, ..._resumable],
      colors: const ChartColors(),
    );
    final live = controller(candles);
    final ticked = _appended(_ticked(candles, 120), 125);
    live.updateInputs(
      interval: const Duration(minutes: 1),
      viewConfig: const ChartViewConfig(),
      candles: ticked,
      viewResetKey: 'BTC',
      formatPrice: (price) => price.toStringAsFixed(1),
      labelStyle: const ChartLabelStyle(),
      indicators: const [..._others, ..._resumable],
      colors: const ChartColors(),
    );
    final fresh = controller(ticked);
    for (final indicator in [..._others, ..._resumable]) {
      _expectSameRender(live.renderOf(indicator), fresh.renderOf(indicator));
    }
    expect(live.paneAxes, fresh.paneAxes);
    expect(live.priceAxis, fresh.priceAxis);
  });

  test('a page prepended, then a shorter list, leave the renders as a fresh controller\'s', () {
    const indicators = [..._others, ..._resumable];
    ChartController controller(List<ChartCandle> candles) => ChartController(
      interval: const Duration(minutes: 1),
      viewConfig: const ChartViewConfig(),
      candles: candles,
      viewResetKey: 'BTC',
      formatPrice: (price) => price.toStringAsFixed(1),
      labelStyle: const ChartLabelStyle(),
      indicators: indicators,
      colors: const ChartColors(),
    );
    final all = _candles(300);
    final live = controller(all.sublist(100));
    for (final candles in [all, all.sublist(0, 200)]) {
      live.updateInputs(
        interval: const Duration(minutes: 1),
        viewConfig: const ChartViewConfig(),
        candles: candles,
        viewResetKey: 'BTC',
        formatPrice: (price) => price.toStringAsFixed(1),
        labelStyle: const ChartLabelStyle(),
        indicators: indicators,
        colors: const ChartColors(),
      );
      final fresh = controller(candles);
      for (final indicator in indicators) {
        _expectSameRender(live.renderOf(indicator), fresh.renderOf(indicator));
      }
    }
  });
}

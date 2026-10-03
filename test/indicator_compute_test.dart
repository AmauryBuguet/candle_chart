import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart/src/internal/indicator_compute.dart';
import 'package:trading_chart/trading_chart.dart';

List<ChartCandle> _candles() => [
  for (var i = 0; i < 80; i++)
    ChartCandle(
      timestamp: i * 3600000,
      endTimestamp: (i + 1) * 3600000,
      open: 100.0 + i % 7,
      high: 103.0 + i % 7,
      low: 98.0 + i % 5,
      close: 101.0 + i % 3,
      volume: 1,
    ),
];

void main() {
  test('a line with no colour is left out of what is drawn', () {
    final levels = renderIndicator(
      const ChartPeriodLevels(
        period: ChartLevelPeriod.day,
        previousHighColor: Colors.green,
        previousLowColor: null,
        openColor: Colors.grey,
        highColor: Colors.blue,
        lowColor: null,
      ),
      _candles(),
      const ChartColors(),
    );
    expect(levels.series.map((s) => s.color), [Colors.green, Colors.grey, Colors.blue]);

    final stochastic = renderIndicator(
      const ChartStochastic(kColor: null, dColor: Colors.red),
      _candles(),
      const ChartColors(),
    );
    expect(stochastic.series.single.color, Colors.red);
  });

  test("Ichimoku's cloud needs both spans", () {
    const full = ChartIchimoku(
      conversionColor: Colors.blue,
      baseColor: Colors.red,
      spanAColor: Colors.green,
      spanBColor: Colors.orange,
      laggingColor: Colors.purple,
    );
    final drawn = renderIndicator(full, _candles(), const ChartColors());
    expect(drawn.series, hasLength(5));
    expect(drawn.bands, hasLength(1));

    const withoutSpanB = ChartIchimoku(
      conversionColor: Colors.blue,
      baseColor: Colors.red,
      spanAColor: Colors.green,
      spanBColor: null,
      laggingColor: null,
    );
    final partial = renderIndicator(withoutSpanB, _candles(), const ChartColors());
    expect(partial.series, hasLength(3));
    expect(partial.bands, isEmpty);
  });

  test("MACD's bars on a side with no colour are not drawn", () {
    final drawn = renderIndicator(
      const ChartMacd(macdColor: Colors.blue, signalColor: Colors.red, upColor: null, downColor: Colors.red),
      _candles(),
      const ChartColors(),
    );
    final histogram = drawn.series.first;
    for (var i = 0; i < histogram.values.length; i++) {
      final value = histogram.values[i];
      if (value != null && value >= 0) expect(histogram.barColors![i], isNull);
    }
    expect(histogram.barColors!.whereType<Color>(), isNotEmpty);
  });

  test('a session with no colour has no box', () {
    final week = DateTime.utc(2025, 10, 13).millisecondsSinceEpoch;
    final candles = [
      for (var i = 0; i < 48; i++)
        ChartCandle(
          timestamp: week + i * 3600000,
          endTimestamp: week + (i + 1) * 3600000,
          open: 100,
          high: 101,
          low: 99,
          close: 100,
          volume: 1,
        ),
    ];
    final drawn = renderIndicator(
      const ChartSessions(asiaColor: null, londonColor: Colors.blue, newYorkColor: Colors.purple),
      candles,
      const ChartColors(),
    );
    expect(drawn.boxes, hasLength(4));
    expect(drawn.boxes.map((b) => b.color), isNot(contains(null)));
  });
}

import 'package:candle_chart/candle_chart.dart';
import 'package:candle_chart/src/painter/chart_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _up = Color(0xFF00AA00);
const _down = Color(0xFFAA0000);
const _style = ChartStyle(
  colors: ChartColors(upCandle: _up, downCandle: _down),
);

/// One-minute candles, the last still forming, closing at [close].
List<ChartCandle> _candles({double close = 101}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final start = now - now % 60000 - 39 * 60000;
  return [
    for (var i = 0; i < 40; i++)
      ChartCandle(
        timestamp: start + i * 60000,
        endTimestamp: start + (i + 1) * 60000 - 1,
        open: 100,
        high: 102,
        low: 98,
        close: i == 39 ? close : 100,
        volume: 1,
      ),
  ];
}

Future<void> _pumpChart(WidgetTester tester, {ChartStyle style = _style, double close = 101}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TradingChart(
          candles: _candles(close: close),
          lines: const [],
          orderLines: const [],
          positions: const [],
          style: style,
          interval: const Duration(minutes: 1),
          viewConfig: const ChartViewConfig(),
          viewResetKey: 'BTC',
          formatPrice: (price) => price.toStringAsFixed(1),
          onPointerDownInChart: (_, _, _, _) {},
          onPointerDownOutsideChart: () {},
          onDragUpdate: (_, _, _) => false,
          onDragEnd: () async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _chart = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ChartPainter);

ChartPainter _painter(WidgetTester tester) => tester.widget<CustomPaint>(_chart).painter! as ChartPainter;

/// The label's box: the only rectangle wider than a candle in [color].
Rect? _label(Color color) {
  Rect? found;
  expect(
    _chart,
    paints..everything((method, arguments) {
      if (method == #drawRect) {
        final rect = arguments[0] as Rect;
        final paint = arguments[1] as Paint;
        if (paint.color.toARGB32() == color.toARGB32() && paint.style == PaintingStyle.fill && rect.width > 20) {
          found = rect;
        }
      }
      return true;
    }),
  );
  return found;
}

void main() {
  testWidgets('the forming candle\'s price is labelled in its colour', (tester) async {
    await _pumpChart(tester);
    expect(_label(_up), isNotNull);
    expect(_label(_down), isNull);

    await _pumpChart(tester, close: 99);
    expect(_label(_down), isNotNull);
    expect(_label(_up), isNull);
  });

  testWidgets('the label counts down to the candle\'s close, a line taller, unless turned off', (tester) async {
    await _pumpChart(tester);
    expect(_painter(tester).candleCountdown, matches(RegExp(r'^\d\d:\d\d$')));
    final withCountdown = _label(_up)!.height;

    await _pumpChart(tester, style: _style.copyWith(candleCountdown: false));
    expect(_painter(tester).candleCountdown, isNull);
    expect(_label(_up)!.height, lessThan(withCountdown));
  });
}

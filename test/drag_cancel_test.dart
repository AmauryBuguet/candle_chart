import 'package:candle_chart/candle_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a gesture the system cancels tells the host, which a pointer-up never will', (tester) async {
    var ends = 0;
    var cancels = 0;
    final start = (DateTime.now().millisecondsSinceEpoch ~/ 60000 - 40) * 60000;
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TradingChart(
            candles: [
              for (var i = 0; i < 40; i++)
                ChartCandle(
                  timestamp: start + i * 60000,
                  endTimestamp: start + (i + 1) * 60000,
                  open: 100.0 + i,
                  high: 102.0 + i,
                  low: 99.0 + i,
                  close: 101.0 + i,
                  volume: 1,
                ),
            ],
            lines: const [],
            orderLines: const [],
            positions: const [],
            style: const ChartStyle(),
            interval: const Duration(minutes: 1),
            viewConfig: const ChartViewConfig(),
            viewResetKey: 'BTC',
            formatPrice: (price) => price.toStringAsFixed(1),
            onPointerDownInChart: (_, _, _, _) {},
            onPointerDownOutsideChart: () {},
            onDragUpdate: (_, _, _) => false,
            onDragEnd: () async {
              ends++;
            },
            onDragCancel: () async {
              cancels++;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(TradingChart));
    final cancelled = await tester.startGesture(center, kind: PointerDeviceKind.touch);
    await cancelled.moveBy(const Offset(40, 10));
    await cancelled.cancel();
    await tester.pumpAndSettle();
    expect((ends, cancels), (0, 1));

    final lifted = await tester.startGesture(center, kind: PointerDeviceKind.touch);
    await lifted.moveBy(const Offset(40, 10));
    await lifted.up();
    await tester.pumpAndSettle();
    expect((ends, cancels), (1, 1));
  });
}

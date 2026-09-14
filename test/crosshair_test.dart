import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart/src/painter/chart_painter.dart';
import 'package:trading_chart/trading_chart.dart';

List<ChartCandle> _candles() {
  final start = DateTime.now().millisecondsSinceEpoch - 40 * 60000;
  return [
    for (var i = 0; i < 40; i++)
      ChartCandle(
        timestamp: start + i * 60000,
        endTimestamp: start + (i + 1) * 60000,
        open: 100,
        high: 101,
        low: 99,
        close: 100,
        volume: 1,
      ),
  ];
}

Future<void> _pumpChart(WidgetTester tester) async {
  // The crosshair is a desktop affordance, so the surface has to be one.
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TradingChart(
          candles: _candles(),
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
          onDragEnd: () async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Offset? _crosshair(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(TradingChart), matching: find.byType(CustomPaint)),
  );
  return (paint.painter! as ChartPainter).crosshairPosition;
}

void main() {
  testWidgets('a hovering mouse arms the crosshair', (tester) async {
    await _pumpChart(tester);

    final center = tester.getCenter(find.byType(TradingChart));
    await tester.sendEventToBinding(
      PointerHoverEvent(position: center, kind: PointerDeviceKind.mouse),
    );
    await tester.pumpAndSettle();

    expect(_crosshair(tester), isNotNull);
  });

  testWidgets('a pointer that is down is dragging, not hovering', (tester) async {
    await _pumpChart(tester);
    final center = tester.getCenter(find.byType(TradingChart));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(center);
    await tester.pumpAndSettle();

    await mouse.down(center);
    await mouse.moveTo(center + const Offset(0, 40));
    await tester.pumpAndSettle();

    expect(_crosshair(tester), isNull);
  });
}

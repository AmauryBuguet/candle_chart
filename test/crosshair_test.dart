import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:candle_chart/src/painter/chart_painter.dart';
import 'package:candle_chart/candle_chart.dart';

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

Future<void> _pumpChart(
  WidgetTester tester, {
  Size size = const Size(1400, 1000),
  ChartStyle style = const ChartStyle(),
}) async {
  // Hover is a desktop affordance, so the surface is one unless said otherwise.
  tester.view.physicalSize = size;
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

  testWidgets('a finger leaving the page is reported as a hover on the web, and never moves the crosshair', (
    tester,
  ) async {
    await _pumpChart(tester, size: const Size(400, 800));
    final center = tester.getCenter(find.byType(TradingChart));
    // The web engine hands the region a hover of kind touch after every
    // lift; the test binding drops it before the region, so it is fed
    // straight in.
    final region = tester.widget<MouseRegion>(
      find.descendant(of: find.byType(TradingChart), matching: find.byType(MouseRegion)),
    );
    await tester.tapAt(center);
    await tester.pump();
    region.onHover!(PointerHoverEvent(position: center + const Offset(80, 80), kind: PointerDeviceKind.touch));
    await tester.pump();
    expect(_crosshair(tester), center);
    await tester.tapAt(center);
    await tester.pump();
    region.onEnter!(PointerEnterEvent(position: center, kind: PointerDeviceKind.touch));
    await tester.pump();
    expect(_crosshair(tester), isNull);
    await tester.pumpAndSettle();
  });

  for (final (name, size) in [
    ('on a phone', const Size(400, 800)),
    ('under a finger on a desktop', const Size(1400, 1000)),
  ]) {
    testWidgets('$name a tap shows the crosshair, a swipe from elsewhere moves it, a tap hides it', (tester) async {
      await _pumpChart(tester, size: size);
      final center = tester.getCenter(find.byType(TradingChart));

      await tester.tapAt(center);
      await tester.pump();
      expect(_crosshair(tester), center);

      await tester.dragFrom(center + const Offset(-100, 200), const Offset(50, 20));
      await tester.pump();
      expect(_crosshair(tester), center + const Offset(50, 20));

      await tester.tapAt(center);
      await tester.pump();
      expect(_crosshair(tester), isNull);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('with the crosshair off a finger\'s tap shows nothing and its swipe pans', (tester) async {
    await _pumpChart(tester, size: const Size(400, 800), style: const ChartStyle(crosshair: false));
    final center = tester.getCenter(find.byType(TradingChart));

    await tester.tapAt(center);
    await tester.pump();
    expect(_crosshair(tester), isNull);

    await tester.dragFrom(center, const Offset(50, 20));
    await tester.pump();
    expect(_crosshair(tester), isNull);
    await tester.pumpAndSettle();
  });
}

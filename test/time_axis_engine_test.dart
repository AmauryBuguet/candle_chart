import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart/trading_chart.dart';
import 'package:trading_chart/src/internal/time_axis_engine.dart';

void main() {
  const interval = Duration(minutes: 15);
  const config = ChartViewConfig(startCandles: 100, rightMargin: 0.25);

  test('reset opens a startCandles window with the right margin ahead of now', () {
    final engine = TimeAxisEngine(interval: interval, viewConfig: config);
    final now = DateTime.now().millisecondsSinceEpoch;
    const range = 100 * 15 * 60 * 1000;

    expect(engine.axis.range, range);
    expect(engine.axis.end - now, closeTo(range * 0.25, 1000));
    expect(engine.isLive, isTrue);
  });

  test('rightMargin of zero ends the window at now', () {
    final engine = TimeAxisEngine(
      interval: interval,
      viewConfig: const ChartViewConfig(startCandles: 100, rightMargin: 0),
    );
    expect(engine.axis.end - DateTime.now().millisecondsSinceEpoch, closeTo(0, 1000));
  });

  test('panning into the past drops out of live, jumpToLive restores it', () {
    final engine = TimeAxisEngine(interval: interval, viewConfig: config);
    final range = engine.axis.range;

    engine.pan(-range);
    expect(engine.isLive, isFalse);

    engine.jumpToLive();
    expect(engine.isLive, isTrue);
    expect(engine.axis.range, range);
  });

  test('jumpToLive keeps the current zoom level', () {
    final engine = TimeAxisEngine(interval: interval, viewConfig: config);
    engine.scale(-engine.axis.range ~/ 2, 0.5);
    final zoomed = engine.axis.range;

    engine.pan(-zoomed * 3);
    engine.jumpToLive();

    expect(engine.axis.range, zoomed);
  });
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:candle_chart/candle_chart.dart';

void main() {
  const transform = ChartTransform(
    size: Size(400, 300),
    margins: ChartMargins(left: 0, top: 10, right: 50, bottom: 20),
    priceAxis: PriceAxis(start: 100, end: 200),
    timeAxis: TimeAxis(start: 1000, end: 2000),
  );

  test('plot area excludes the axis gutters', () {
    expect(transform.plotArea, const Rect.fromLTRB(0, 10, 350, 280));
  });

  test('maps prices onto the plot area, low price at the bottom', () {
    expect(transform.yForPrice(100), 280);
    expect(transform.yForPrice(200), 10);
    expect(transform.yForPrice(150), 145);
  });

  test('maps timestamps onto the plot area', () {
    expect(transform.xForTime(1000), 0);
    expect(transform.xForTime(2000), 350);
    expect(transform.xForTime(1500), 175);
  });

  test('round-trips pixels back to prices and times', () {
    expect(transform.priceForY(transform.yForPrice(137.5)), closeTo(137.5, 1e-9));
    expect(transform.timeForX(transform.xForTime(1234)), 1234);
  });

  test('containsPrice covers the visible range only', () {
    expect(transform.containsPrice(150), isTrue);
    expect(transform.containsPrice(99), isFalse);
    expect(transform.containsPrice(201), isFalse);
  });
}

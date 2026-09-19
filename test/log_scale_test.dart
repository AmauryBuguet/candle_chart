import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart/trading_chart.dart';

void main() {
  const transform = ChartTransform(
    size: Size(400, 300),
    margins: ChartMargins(left: 0, top: 0, right: 0, bottom: 0),
    priceAxis: PriceAxis(start: 10, end: 1000),
    timeAxis: TimeAxis(start: 1000, end: 2000),
    logScale: true,
  );

  test('equal ratios take equal heights on a log scale', () {
    expect(transform.yForPrice(10), 300);
    expect(transform.yForPrice(1000), 0);
    expect(transform.yForPrice(100), closeTo(150, 1e-9));
  });

  test('round-trips through the log mapping', () {
    expect(transform.priceForY(transform.yForPrice(37)), closeTo(37, 1e-9));
    expect(transform.priceForY(75), closeTo(316.2277, 1e-3));
  });
}

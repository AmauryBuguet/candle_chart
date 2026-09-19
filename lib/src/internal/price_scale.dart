import 'dart:math';

import 'package:flutter/widgets.dart';

import '../models/axis.dart';

/// The one place prices become pixels and back: linear, or logarithmic
/// when [logScale] is on, in which case equal ratios take equal heights.
/// A non-positive price cannot be placed on a log scale and is clamped
/// to the bottom of the axis.
double yForPrice(double price, PriceAxis axis, Rect rect, {required bool logScale}) {
  final ratio = logScale ? _logRatio(price, axis) : (price - axis.start) / axis.range;
  return rect.top + (1 - ratio) * rect.height;
}

double priceForY(double y, PriceAxis axis, Rect rect, {required bool logScale}) {
  final ratio = (rect.bottom - y) / rect.height;
  if (!logScale) return axis.start + ratio * axis.range;
  final start = max(axis.start, _logFloor);
  final end = max(axis.end, start * 1.0001);
  return exp(log(start) + ratio * (log(end) - log(start)));
}

double _logRatio(double price, PriceAxis axis) {
  final start = max(axis.start, _logFloor);
  final end = max(axis.end, start * 1.0001);
  if (price <= _logFloor) return 0;
  return (log(price) - log(start)) / (log(end) - log(start));
}

const double _logFloor = 1e-12;

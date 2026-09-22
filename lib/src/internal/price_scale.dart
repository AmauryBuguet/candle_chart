import 'package:flutter/widgets.dart';

import '../models/axis.dart';

/// The one place prices become pixels and back.
double yForPrice(double price, PriceAxis axis, Rect rect) {
  final ratio = (price - axis.start) / axis.range;
  return rect.top + (1 - ratio) * rect.height;
}

double priceForY(double y, PriceAxis axis, Rect rect) {
  final ratio = (rect.bottom - y) / rect.height;
  return axis.start + ratio * axis.range;
}

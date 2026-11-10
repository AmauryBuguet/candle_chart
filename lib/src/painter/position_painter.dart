import 'dart:ui';

import '../internal/drawing_geometry.dart';
import '../models/axis.dart';
import '../models/chart_candle.dart';
import '../models/chart_position.dart';
import '../models/chart_style.dart';
import 'position_samples.dart';

/// Draws each position's P&L in the price pane: the price path from entry
/// to exit shaded green where it is in profit and red where at a loss, with
/// the entry and exit marked.
class PositionPainter {
  PositionPainter({
    required this.canvas,
    required this.projection,
    required this.candles,
    required this.timeAxis,
    required this.style,
  });

  final Canvas canvas;

  /// The price pane's mapping.
  final DrawingProjection projection;
  final List<ChartCandle> candles;
  final TimeAxis timeAxis;
  final ChartStyle style;

  void draw(List<ChartPosition> positions) {
    final chartRect = projection.rect;
    canvas.save();
    canvas.clipRect(chartRect);

    final double timeScale = chartRect.width / timeAxis.range;

    double getX(int t) => chartRect.left + (t - timeAxis.start) * timeScale;
    double getY(double p) => projection.yForPrice(p);

    for (final position in positions) {
      final bool isOpen = position.exit == null;
      if (isOpen && candles.isEmpty) continue;

      // A forming candle's close is the live price, and it is drawn at the
      // right edge of that candle's slot rather than at its centre.
      final int exitTimestamp = isOpen ? closeTime(candles.last) : position.exit!.timestamp;
      final double exitPrice = isOpen ? candles.last.close : position.exit!.price;

      if (exitTimestamp < timeAxis.start || position.entry.timestamp > timeAxis.end) {
        continue;
      }

      final double entryX = getX(position.entry.timestamp);
      final double entryY = getY(position.entry.price);
      final double exitX = getX(exitTimestamp);
      final double exitY = getY(exitPrice);

      final bool isLong = position.side == ChartPositionSide.long;
      final Path winPath = Path();
      final Path lossPath = Path();

      int getState(double p) {
        if ((p - position.entry.price).abs() < 0.000001) return 0;
        if (isLong) return p > position.entry.price ? 1 : -1;
        return p < position.entry.price ? 1 : -1;
      }

      void startPath(int state, double x, double y) {
        if (state == 1) {
          winPath.moveTo(x, y);
        } else if (state == -1) {
          lossPath.moveTo(x, y);
        }
      }

      void addToPath(int state, double x, double y) {
        if (state == 1) {
          winPath.lineTo(x, y);
        } else if (state == -1) {
          lossPath.lineTo(x, y);
        }
      }

      void closeActivePath(int state) {
        if (state == 1) {
          winPath.close();
        } else if (state == -1) {
          lossPath.close();
        }
      }

      double prevX = entryX;
      double prevY = entryY;
      double prevPrice = position.entry.price;
      int currentPathState = 0;

      final List<(int, double)> samples = positionSamples(
        candles: candles,
        entryTimestamp: position.entry.timestamp,
        exitTimestamp: exitTimestamp,
        exitPrice: exitPrice,
      );

      int i = 0;
      while (true) {
        final (int nextTs, double nextPrice) = samples[i];
        final bool isLast = i == samples.length - 1;

        final double nextX = getX(nextTs);
        final double nextY = getY(nextPrice);

        int prevState = getState(prevPrice);
        int nextState = getState(nextPrice);

        if (prevState != 0 && nextState != 0 && prevState != nextState) {
          double ratio = (position.entry.price - prevPrice) / (nextPrice - prevPrice);
          double interX = prevX + (nextX - prevX) * ratio;

          addToPath(currentPathState, interX, entryY);
          closeActivePath(currentPathState);

          currentPathState = nextState;
          startPath(currentPathState, interX, entryY);
          addToPath(currentPathState, nextX, nextY);
        } else if (prevState == 0 && nextState != 0) {
          if (currentPathState == 0) {
            currentPathState = nextState;
            startPath(currentPathState, prevX, prevY);
            addToPath(currentPathState, nextX, nextY);
          } else if (currentPathState != nextState) {
            closeActivePath(currentPathState);
            currentPathState = nextState;
            startPath(currentPathState, prevX, prevY);
            addToPath(currentPathState, nextX, nextY);
          } else {
            addToPath(currentPathState, nextX, nextY);
          }
        } else {
          if (currentPathState != 0) {
            addToPath(currentPathState, nextX, nextY);
          }
        }

        prevX = nextX;
        prevY = nextY;
        prevPrice = nextPrice;

        if (isLast) break;
        i++;
      }

      if (currentPathState != 0) {
        if (currentPathState == 1) {
          winPath.lineTo(prevX, entryY);
        } else {
          lossPath.lineTo(prevX, entryY);
        }

        closeActivePath(currentPathState);
      }

      canvas.drawPath(
        winPath,
        Paint()
          ..color = style.colors.positionProfit.withAlpha(100)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        lossPath,
        Paint()
          ..color = style.colors.positionLoss.withAlpha(100)
          ..style = PaintingStyle.fill,
      );

      final dotPaint = Paint()
        ..color = isLong ? style.colors.positionProfit : style.colors.positionLoss
        ..style = PaintingStyle.fill
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 12.0;

      canvas.drawPoints(PointMode.points, [Offset(entryX, entryY)], dotPaint);

      if (!isOpen) {
        dotPaint.color = isLong ? style.colors.positionLoss : style.colors.positionProfit;
        canvas.drawPoints(PointMode.points, [Offset(exitX, exitY)], dotPaint);
      }
    }

    canvas.restore();
  }
}

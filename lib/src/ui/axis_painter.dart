import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/projection.dart';
import 'package:rubin_chart/src/models/axes/ticks.dart';
import 'package:rubin_chart/src/theme/theme.dart';

/// Paint the frame, axes, and tick marks of a plot.
class AxisPainter extends CustomPainter {
  final List<ChartAxis> axes;
  final List<AxisTicks?> ticks;
  final ChartTheme theme;
  final Map<AxisLocation, List<TextPainter>?> _tickLabels = {};
  final double tickPadding;

  /// The projection used for the series.
  ProjectionInitializer projectionInitializer;

  late double leftMargin;
  late double rightMargin;
  late double topMargin;
  late double bottomMargin;

  AxisPainter({
    required this.axes,
    required this.ticks,
    required this.projectionInitializer,
    required this.theme,
    this.tickPadding = 10,
  }) {
    leftMargin = 0;
    rightMargin = 0;
    topMargin = 0;
    bottomMargin = 0;

    for (int i = 0; i < axes.length; i++) {
      AxisTicks? ticks = this.ticks[i];
      AxisLocation location = axes[i].location;

      if (ticks != null) {
        _tickLabels[location] = [];
        for (int j = 0; j < ticks.ticks.length; j++) {
          TextPainter painter = TextPainter(
            text: TextSpan(
              text: ticks.tickLabels[j].toString(),
              style: theme.tickLabelStyle,
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          _tickLabels[location]!.add(painter);

          if (location == AxisLocation.left) {
            leftMargin = math.max(leftMargin, painter.width);
          } else if (location == AxisLocation.right) {
            rightMargin = math.max(rightMargin, painter.width);
          } else if (location == AxisLocation.bottom) {
            bottomMargin = math.max(bottomMargin, painter.height);
          } else if (location == AxisLocation.top) {
            topMargin = math.max(topMargin, painter.height);
          }
        }
      }
    }
  }

  void _drawTick(
      Canvas canvas, Size size, double tick, AxisLocation location, Projection projection, Paint paint) {
    if (location == AxisLocation.left) {
      double y = projection.yTransform.map(tick);
      canvas.drawLine(Offset(leftMargin + tickPadding, topMargin + tickPadding + y),
          Offset(leftMargin + tickPadding + theme.tickLength, topMargin + tickPadding + y), paint);
    } else if (location == AxisLocation.bottom) {
      double x = projection.xTransform.map(tick);
      canvas.drawLine(
          Offset(leftMargin + tickPadding + x, topMargin + tickPadding + size.height),
          Offset(leftMargin + tickPadding + x, topMargin + tickPadding + size.height - theme.tickLength),
          paint);
    }
  }

  void _drawAxisTickLabels(Canvas canvas, Size size, int index, Projection projection) {
    AxisTicks ticks = this.ticks[index]!;
    ChartAxis axis = axes[index];
    bool minIsBound = ticks.bounds.min == axis.bounds.min;
    bool maxIsBound = ticks.bounds.max == axis.bounds.max;

    for (int i = 0; i < ticks.ticks.length; i++) {
      if (i == 0 && minIsBound || i == ticks.ticks.length - 1 && maxIsBound) {
        continue;
      }
      TextPainter painter = _tickLabels[axis.location]![i];
      late Offset offset;

      if (axis.location == AxisLocation.left) {
        double y = projection.yTransform.map(ticks.ticks[i]);
        offset = Offset(leftMargin - painter.width, y + topMargin + tickPadding - painter.height / 2);
      } else if (axis.location == AxisLocation.bottom) {
        double x = projection.xTransform.map(ticks.ticks[i]);
        offset = Offset(
            x + leftMargin + tickPadding - painter.width / 2, topMargin + 2 * tickPadding + size.height);
      } else if (axis.location == AxisLocation.right) {
        double y = projection.yTransform.map(ticks.ticks[i]);
        offset = Offset(
            leftMargin + 2 * tickPadding + size.width, y + topMargin + tickPadding - painter.height / 2);
      } else if (axis.location == AxisLocation.top) {
        double x = projection.xTransform.map(ticks.ticks[i]);
        offset = Offset(x + leftMargin - painter.width / 2, 0);
      }

      painter.paint(canvas, offset);
    }
  }

  Projection? projection;

  @override
  void paint(Canvas canvas, Size size) {
    Size plotSize = Size(size.width - leftMargin - rightMargin - 2 * tickPadding,
        size.height - topMargin - bottomMargin - 2 * tickPadding);

    projection = projectionInitializer(
      axes: axes,
      plotSize: plotSize,
    );

    // TODO: draw the grid

    // Draw the ticks
    if (theme.tickColor != null) {
      Paint tickPaint = Paint()
        ..color = theme.tickColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = theme.tickThickness;
      for (int i = 0; i < axes.length; i++) {
        ChartAxis axis = axes[i];
        AxisTicks? ticks = this.ticks[i];
        if (ticks != null) {
          for (double tick in ticks.ticks) {
            _drawTick(canvas, plotSize, tick, axis.location, projection!, tickPaint);
          }
          _drawAxisTickLabels(canvas, plotSize, i, projection!);
        }
      }
    }

    // TODO: draw the tick labels

    if (theme.frameColor != null) {
      // Draw the frame
      Paint framePaint = Paint()
        ..color = theme.frameColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = theme.frameLineThickness;
      canvas.drawRect(Offset(leftMargin + tickPadding, topMargin + tickPadding) & plotSize, framePaint);
    }
  }

  @override
  bool shouldRepaint(AxisPainter oldDelegate) {
    return true;
    //return oldDelegate.axes != axes;
  }
}

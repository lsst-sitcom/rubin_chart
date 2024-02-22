import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/projection.dart';
import 'package:rubin_chart/src/models/axes/ticks.dart';
import 'package:rubin_chart/src/theme/theme.dart';

/// Paint the frame, axes, and tick marks of a plot.
class AxisPainter extends CustomPainter {
  final Map<Object, ChartAxes> allAxes;
  final ChartTheme theme;
  final Map<AxisId, List<TextPainter>?> _tickLabelPainters = {};
  final double tickPadding;

  late EdgeInsets margin;

  AxisPainter({
    required this.allAxes,
    required this.theme,
    this.tickPadding = 10,
  }) {
    margin = EdgeInsets.zero;

    for (ChartAxes axes in allAxes.values) {
      for (AxisId axisId in axes.axes.keys) {
        ChartAxis axis = axes[axisId];
        if (!(axis.showTicks || axis.showLabels)) {
          continue;
        }
        AxisTicks ticks = axis.ticks;

        _tickLabelPainters[axisId] = [];
        for (int j = 0; j < ticks.ticks.length; j++) {
          TextPainter painter = TextPainter(
            text: TextSpan(
              text: ticks.tickLabels[j].toString(),
              style: theme.tickLabelStyle,
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          _tickLabelPainters[axisId]!.add(painter);

          margin = axes.updateMargin(axisId, margin, painter);
        }
      }
    }
  }

  void _drawTick(
      Canvas canvas, Size size, double tick, AxisLocation location, Projection projection, Paint paint) {
    if (location == AxisLocation.left) {
      double y = projection.yTransform.map(tick);
      canvas.drawLine(Offset(margin.left + tickPadding, margin.top + tickPadding + y),
          Offset(margin.left + tickPadding + theme.tickLength, margin.top + tickPadding + y), paint);
    } else if (location == AxisLocation.bottom) {
      double x = projection.xTransform.map(tick);
      canvas.drawLine(
          Offset(margin.left + tickPadding + x, margin.top + tickPadding + size.height),
          Offset(margin.left + tickPadding + x, margin.top + tickPadding + size.height - theme.tickLength),
          paint);
    } else if (location == AxisLocation.right) {
      double y = projection.yTransform.map(tick);
      canvas.drawLine(
          Offset(margin.left + tickPadding + size.width, margin.top + tickPadding + y),
          Offset(margin.left + tickPadding + size.width - theme.tickLength, margin.top + tickPadding + y),
          paint);
    } else if (location == AxisLocation.top) {
      double x = projection.xTransform.map(tick);
      canvas.drawLine(Offset(margin.left + tickPadding + x, margin.top + tickPadding),
          Offset(margin.left + tickPadding + x, margin.top + tickPadding + theme.tickLength), paint);
    } else {
      throw UnimplementedError("Unknown axis location: $location");
    }
  }

  void _drawAxisTickLabels(Canvas canvas, Size size, AxisId axisId, Projection projection, Object axesId) {
    ChartAxis axis = allAxes[axesId]![axisId];
    AxisTicks ticks = axis.ticks;
    bool minIsBound = ticks.bounds.min == axis.bounds.min;
    bool maxIsBound = ticks.bounds.max == axis.bounds.max;

    for (int i = 0; i < ticks.ticks.length; i++) {
      if (i == 0 && minIsBound || i == ticks.ticks.length - 1 && maxIsBound) {
        continue;
      }
      TextPainter painter = _tickLabelPainters[axisId]![i];
      late Offset offset;

      if (axisId.location == AxisLocation.left) {
        double y = projection.yTransform.map(ticks.ticks[i]);
        offset = Offset(margin.left - painter.width, y + margin.top + tickPadding - painter.height / 2);
      } else if (axisId.location == AxisLocation.bottom) {
        double x = projection.xTransform.map(ticks.ticks[i]);
        offset = Offset(
            x + margin.left + tickPadding - painter.width / 2, margin.top + 2 * tickPadding + size.height);
      } else if (axisId.location == AxisLocation.right) {
        double y = projection.yTransform.map(ticks.ticks[i]);
        offset = Offset(
            margin.left + 2 * tickPadding + size.width, y + margin.top + tickPadding - painter.height / 2);
      } else if (axisId.location == AxisLocation.top) {
        double x = projection.xTransform.map(ticks.ticks[i]);
        offset = Offset(x + margin.left - painter.width / 2, 0);
      } else {
        throw UnimplementedError("Unknown axis location: ${axisId.location}");
      }

      painter.paint(canvas, offset);
    }
  }

  Map<Object, Projection>? projections;

  @override
  void paint(Canvas canvas, Size size) {
    projections = {};
    Size plotSize = Size(size.width - margin.left - margin.right - 2 * tickPadding,
        size.height - margin.top - margin.bottom - 2 * tickPadding);

    // TODO: draw the grid

    // Draw the ticks
    if (theme.tickColor != null) {
      Paint tickPaint = Paint()
        ..color = theme.tickColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = theme.tickThickness;
      for (MapEntry entry in allAxes.entries) {
        Object axesId = entry.key;
        ChartAxes axes = entry.value;
        projections![axesId] = axes.projection(axes: axes.axes.values.toList(), plotSize: plotSize);
        for (AxisId axisId in axes.axes.keys) {
          ChartAxis axis = axes[axisId];
          if (!(axis.showTicks || axis.showLabels)) {
            continue;
          }
          AxisTicks ticks = axis.ticks;
          for (double tick in ticks.ticks) {
            _drawTick(canvas, plotSize, tick, axisId.location, projections![axesId]!, tickPaint);
          }
          _drawAxisTickLabels(canvas, plotSize, axisId, projections![axesId]!, axesId);
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
      canvas.drawRect(Offset(margin.left + tickPadding, margin.top + tickPadding) & plotSize, framePaint);
    }
  }

  @override
  bool shouldRepaint(AxisPainter oldDelegate) {
    return true;
    //return oldDelegate.axes != axes;
  }
}

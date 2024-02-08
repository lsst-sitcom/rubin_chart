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
  List<List<TextPainter>?> _tickLabels;

  /// The projection used for the series.
  ProjectionInitializer projectionInitializer;

  /// Offset from the lower left to make room for labels.
  Offset labelOffset;

  AxisPainter({
    required this.axes,
    required this.ticks,
    required this.projectionInitializer,
    required this.labelOffset,
    required this.theme,
  }) {
    double leftMargin = 0;
    double rightMargin = 0;
    double topMargin = 0;
    double bottomMargin = 0;

    for (int i = 0; i < axes.length; i++) {
      ChartAxis axis = axes[i];
      AxisTicks? ticks = this.ticks[i];
      _tickLabels = [];
      if (ticks != null) {
        for (double tick in ticks.ticks) {
          TextSpan textSpan = TextSpan(text: text, style: style);
          TextPainter painter = TextPainter(
            text: textSpan,
            maxLines: 1,
            textDirection: textDirection,
          )..layout();
          _tickLabels[i]!.add();
        }
      }
    }
  }

  void _drawTick(
      Canvas canvas, Size size, double tick, AxisLocation location, Projection projection, Paint paint) {
    if (location == AxisLocation.left) {
      double y = projection.yTransform.map(tick);
      canvas.drawLine(Offset(labelOffset.dx, y), Offset(labelOffset.dx + theme.tickLength, y), paint);
    }

    if (location == AxisLocation.bottom) {
      double x = projection.xTransform.map(tick);
      canvas.drawLine(Offset(x, labelOffset.dy + size.height),
          Offset(x, labelOffset.dy + size.height - theme.tickLength), paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    Projection<num> projection = projectionInitializer(
      axes: axes,
      plotSize: size,
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
            _drawTick(canvas, size, tick, axis.location, projection, tickPaint);
          }
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
      canvas.drawRect(labelOffset & size, framePaint);
    }
  }

  @override
  bool shouldRepaint(AxisPainter oldDelegate) {
    return oldDelegate.axes != axes;
  }
}

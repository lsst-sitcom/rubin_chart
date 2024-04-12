/// This file is part of the rubin_chart package.
///
/// Developed for the LSST Data Management System.
/// This product includes software developed by the LSST Project
/// (https://www.lsst.org).
/// See the COPYRIGHT file at the top-level directory of this distribution
/// for details of code ownership.
///
/// This program is free software: you can redistribute it and/or modify
/// it under the terms of the GNU General Public License as published by
/// the Free Software Foundation, either version 3 of the License, or
/// (at your option) any later version.
///
/// This program is distributed in the hope that it will be useful,
/// but WITHOUT ANY WARRANTY; without even the implied warranty of
/// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
/// GNU General Public License for more details.
///
/// You should have received a copy of the GNU General Public License
/// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/axes/axes.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/ticks.dart';
import 'package:rubin_chart/src/theme/theme.dart';

/// A function that initializes an [AxisPainter].
typedef AxisPainterInitializer = AxisPainter Function({
  required Map<Object, ChartAxes> allAxes,
  required ChartTheme theme,
  double tickPadding,
});

/// Paint the frame, axes, and tick marks of a plot.
abstract class AxisPainter extends CustomPainter {
  final Map<Object, ChartAxes> allAxes;
  final ChartTheme theme;
  final Map<AxisId, List<TextPainter>?> tickLabelPainters = {};
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
        if (!axis.showLabels) {
          continue;
        }
        AxisTicks ticks = axis.ticks;

        tickLabelPainters[axisId] = [];
        for (int j = 0; j < ticks.majorTicks.length; j++) {
          TextPainter painter = TextPainter(
            text: TextSpan(
              text: ticks.tickLabels[j].toString(),
              style: theme.tickLabelStyle,
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          tickLabelPainters[axisId]!.add(painter);

          margin = axes.updateMargin(axisId, margin, painter);
        }
      }
    }
  }

  /// The size of the chart canvas.
  late Size chartSize;

  /// Whether or not to clip the canvas at the chart area.
  bool get clip;

  /// Draw a tick mark on the axis.
  void drawTick(
    Canvas canvas,
    Size size,
    double tick,
    AxisLocation location,
    Paint paint,
    ChartAxes chartAxes,
    double tickLength,
  );

  /// Draw the tick labels on the axis.
  void drawTickLabels(Canvas canvas, Size size, ChartAxis axis, ChartAxes chartAxes);

  @override
  void paint(Canvas canvas, Size size) {
    chartSize = Size(size.width - margin.left - margin.right - 2 * tickPadding,
        size.height - margin.top - margin.bottom - 2 * tickPadding);

    // Make sure not to draw outside of the chart area.
    if (clip) {
      canvas.clipRect(Offset(margin.left + tickPadding, margin.top + tickPadding) & chartSize);
    }

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
        for (AxisId axisId in axes.axes.keys) {
          ChartAxis axis = axes[axisId];
          if (axis.showTicks) {
            AxisTicks ticks = axis.ticks;
            for (double tick in ticks.majorTicks) {
              drawTick(canvas, chartSize, tick, axisId.location, tickPaint, axes, theme.majorTickLength);
            }
            for (double tick in ticks.minorTicks) {
              drawTick(canvas, chartSize, tick, axisId.location, tickPaint, axes, theme.minorTickLength);
            }
          }

          if (axis.showLabels) {
            drawTickLabels(canvas, chartSize, allAxes[axesId]![axisId], axes);
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
      canvas.drawRect(Offset(margin.left + tickPadding, margin.top + tickPadding) & chartSize, framePaint);
    }
  }

  @override
  bool shouldRepaint(AxisPainter oldDelegate) {
    return true;
    //return oldDelegate.axes != axes;
  }
}

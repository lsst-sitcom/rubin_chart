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
import 'package:rubin_chart/src/ui/axis_painter.dart';
import 'package:rubin_chart/src/ui/chart.dart';
import 'package:rubin_chart/src/ui/charts/scatter.dart';
import 'package:rubin_chart/src/utils/utils.dart';

/// Axes for a Cartesian chart.
class CartesianChartAxes extends ChartAxes {
  /// The ID of the x-axis.
  late final AxisId xAxisId;

  /// The ID of the y-axis.
  late final AxisId yAxisId;

  CartesianChartAxes({required super.axes}) {
    // Extract and set the x and y axes from the map of axes.
    AxisId? xAxisId;
    AxisId? yAxisId;
    for (AxisId axisId in axes.keys) {
      AxisLocation location = axes[axisId]!.info.axisId.location;
      if (location == AxisLocation.bottom || location == AxisLocation.top) {
        xAxisId = axisId;
      } else if (location == AxisLocation.left || location == AxisLocation.right) {
        yAxisId = axisId;
      } else {
        throw AxesInitializationException("Unknown axis location: $location");
      }
    }
    this.xAxisId = xAxisId!;
    this.yAxisId = yAxisId!;
  }

  /// Create a new [CartesianChartAxes] from a map of axes.
  static CartesianChartAxes fromAxes({required Map<AxisId, ChartAxis> axes}) =>
      CartesianChartAxes(axes: axes);

  /// Get the x-axis.
  ChartAxis get xAxis => axes[xAxisId]!;

  /// Get the y-axis.
  ChartAxis get yAxis => axes[yAxisId]!;

  @override
  Bounds<double> get xBounds => Bounds<double>(
        xAxis.info.mapping.map(xAxis.bounds.min),
        xAxis.info.mapping.map(xAxis.bounds.max),
      );

  @override
  Bounds<double> get yBounds => Bounds<double>(
        yAxis.info.mapping.map(yAxis.bounds.min),
        yAxis.info.mapping.map(yAxis.bounds.max),
      );

  /// Return an [Offset] from a pair of [double] x, y coordinates.
  @override
  Offset doubleToLinear(List<double> data) {
    if (data.length != 2) {
      throw ChartInitializationException("Cartesian projection requires two coordinates, got ${data.length}");
    }
    return Offset(xAxis.info.mapping.map(data[0]), yAxis.info.mapping.map(data[1]));
  }

  /// Return a pair of [double] x, y coordinates from an [Offset].
  @override
  List<double> doubleFromLinear(Offset cartesian) => [
        xAxis.info.mapping.inverse(cartesian.dx),
        yAxis.info.mapping.inverse(cartesian.dy),
      ];

  /// Convert x values into pixel values.
  @override
  double xLinearToPixel({required double x, required double chartWidth}) {
    double xMin = xBounds.min;
    double xMax = xBounds.max;
    double px = (x - xMin) / (xMax - xMin) * chartWidth;
    if (xAxis.info.isInverted) {
      px = chartWidth - px;
    }
    return px;
  }

  /// Convert pixel x values into native x values.
  @override
  double xLinearFromPixel({required double px, required double chartWidth}) {
    if (xAxis.info.isInverted) {
      px = chartWidth - px;
    }
    double xMin = xBounds.min;
    double xMax = xBounds.max;
    return px / chartWidth * (xMax - xMin) + xMin;
  }

  /// Convert y values into pixel values.
  @override
  double yLinearToPixel({required double y, required double chartHeight}) {
    double yMin = yBounds.min;
    double yMax = yBounds.max;
    double py = (y - yMin) / (yMax - yMin) * chartHeight;
    if (yAxis.info.isInverted) {
      py = chartHeight - py;
    }
    return py;
  }

  /// Convert pixel y values into native y values.
  @override
  double yLinearFromPixel({required double py, required double chartHeight}) {
    if (yAxis.info.isInverted) {
      py = chartHeight - py;
    }
    double yMin = yBounds.min;
    double yMax = yBounds.max;
    return py / chartHeight * (yMax - yMin) + yMin;
  }

  @override
  Rect get linearRect => Rect.fromPoints(
        Offset(xBounds.min, yBounds.min),
        Offset(xBounds.max, yBounds.max),
      );

  /// Translate a single [ChartAxis] by a given amount.
  void _translateAxis(ChartAxis axis, double min, double max, double delta) {
    if (max < min) {
      double temp = min;
      min = max;
      max = temp;
      delta = -delta;
    }
    if ((delta < 0 && (min > axis.dataBounds.min || max > axis.dataBounds.max)) ||
        (delta > 0 && (min < axis.dataBounds.min || max < axis.dataBounds.max))) {
      axis.updateTicksAndBounds(Bounds(min, max));
    }
  }

  /// Translate the displayed axes by a given amount.
  @override
  void translate(Offset delta, Size chartSize) {
    Offset newMin = delta;
    Offset newMax = Offset(chartSize.width, chartSize.height) + delta;
    List<double> translatedMin = doubleFromPixel(newMin, chartSize);
    List<double> translatedMax = doubleFromPixel(newMax, chartSize);
    _translateAxis(xAxis, translatedMin[0], translatedMax[0], delta.dx);
    _translateAxis(yAxis, translatedMin[1], translatedMax[1], delta.dy);
  }

  /// Scale the displayed axes by a given amount.
  @override
  void scale(double scaleX, double scaleY, Size chartSize) {
    Offset linearMin = doubleToLinear([xAxis.bounds.min, yAxis.bounds.min]);
    Offset linearMax = doubleToLinear([xAxis.bounds.max, yAxis.bounds.max]);
    Offset center = (linearMin + linearMax) / 2;
    double xRange = linearMax.dx - linearMin.dx;
    double yRange = linearMax.dy - linearMin.dy;
    double xDelta = xRange / scaleX / 2;
    double yDelta = yRange / scaleY / 2;
    List<double> newMin = doubleFromLinear(center - Offset(xDelta, yDelta));
    List<double> newMax = doubleFromLinear(center + Offset(xDelta, yDelta));
    xAxis.updateTicksAndBounds(Bounds(newMin[0], newMax[0]));
    yAxis.updateTicksAndBounds(Bounds(newMin[1], newMax[1]));
  }
}

/// A class for storing information about a Cartesian scatter plot.
class CartesianScatterPlotInfo extends ScatterPlotInfo {
  CartesianScatterPlotInfo({
    required super.id,
    required super.allSeries,
    required super.key,
    super.title,
    super.theme,
    super.legend,
    super.axisInfo,
    super.colorCycle,
    super.interiorAxisLabelLocation,
    super.flexX,
    super.flexY,
    super.xToYRatio,
    super.cursorAction,
  });

  @override
  Map<Object, ChartAxes> initializeAxes({required Set<Object> drillDownDataPoints}) => initializeSimpleAxes(
        seriesList: allSeries,
        axisInfo: axisInfo,
        theme: theme,
        axesInitializer: CartesianChartAxes.fromAxes,
        drillDownDataPoints: drillDownDataPoints,
      );

  @override
  AxisPainter initializeAxesPainter({required Map<Object, ChartAxes> allAxes, required ChartTheme theme}) =>
      CartesianAxisPainter.fromAxes(
        allAxes: allAxes,
        theme: theme,
      );
}

/// A class for painting axes, including ticks, on a Cartesian chart.
class CartesianAxisPainter extends AxisPainter {
  CartesianAxisPainter({
    required super.allAxes,
    required super.theme,
    super.tickPadding = 10,
  });

  static CartesianAxisPainter fromAxes({
    required Map<Object, ChartAxes> allAxes,
    required ChartTheme theme,
    double tickPadding = 10,
  }) =>
      CartesianAxisPainter(allAxes: allAxes, theme: theme, tickPadding: tickPadding);

  @override
  void drawTick(
    Canvas canvas,
    Size size,
    double tick,
    AxisLocation location,
    Paint paint,
    ChartAxes chartAxes,
    double tickLength,
  ) {
    if (location == AxisLocation.left) {
      double y = chartAxes.yLinearToPixel(y: tick, chartHeight: size.height);
      canvas.drawLine(Offset(margin.left + tickPadding, margin.top + tickPadding + y),
          Offset(margin.left + tickPadding + tickLength, margin.top + tickPadding + y), paint);
    } else if (location == AxisLocation.bottom) {
      double x = chartAxes.xLinearToPixel(x: tick, chartWidth: size.width);
      canvas.drawLine(Offset(margin.left + tickPadding + x, margin.top + tickPadding + size.height),
          Offset(margin.left + tickPadding + x, margin.top + tickPadding + size.height - tickLength), paint);
    } else if (location == AxisLocation.right) {
      double y = chartAxes.yLinearToPixel(y: tick, chartHeight: size.height);
      canvas.drawLine(Offset(margin.left + tickPadding + size.width, margin.top + tickPadding + y),
          Offset(margin.left + tickPadding + size.width - tickLength, margin.top + tickPadding + y), paint);
    } else if (location == AxisLocation.top) {
      double x = chartAxes.xLinearToPixel(x: tick, chartWidth: size.width);
      canvas.drawLine(Offset(margin.left + tickPadding + x, margin.top + tickPadding),
          Offset(margin.left + tickPadding + x, margin.top + tickPadding + tickLength), paint);
    } else {
      throw UnimplementedError("Unknown axis location: $location");
    }
  }

  @override
  void drawTickLabels(Canvas canvas, Size size, ChartAxis axis, ChartAxes chartAxes) {
    AxisId axisId = axis.info.axisId;
    AxisTicks ticks = axis.ticks;
    bool minIsBound = ticks.majorTicks.isNotEmpty && ticks.majorTicks.first == axis.bounds.min;
    bool maxIsBound = ticks.majorTicks.isNotEmpty && ticks.majorTicks.last == axis.bounds.max;

    for (int i = 0; i < ticks.majorTicks.length; i++) {
      if (i == 0 && minIsBound || i == ticks.majorTicks.length - 1 && maxIsBound) {
        continue;
      }
      TextPainter painter = tickLabelPainters[axisId]![i];
      late Offset offset;

      if (axisId.location == AxisLocation.left) {
        double y = chartAxes.yLinearToPixel(y: ticks.majorTicks[i], chartHeight: size.height);
        offset = Offset(margin.left - painter.width, y + margin.top + tickPadding - painter.height / 2);
      } else if (axisId.location == AxisLocation.bottom) {
        double x = chartAxes.xLinearToPixel(x: ticks.majorTicks[i], chartWidth: size.width);
        offset = Offset(
            x + margin.left + tickPadding - painter.width / 2, margin.top + 2 * tickPadding + size.height);
      } else if (axisId.location == AxisLocation.right) {
        double y = chartAxes.yLinearToPixel(y: ticks.majorTicks[i], chartHeight: size.height);
        offset = Offset(
            margin.left + 2 * tickPadding + size.width, y + margin.top + tickPadding - painter.height / 2);
      } else if (axisId.location == AxisLocation.top) {
        double x = chartAxes.xLinearToPixel(x: ticks.majorTicks[i], chartWidth: size.width);
        offset = Offset(x + margin.left - painter.width / 2, 0);
      } else {
        throw UnimplementedError("Unknown axis location: ${axisId.location}");
      }

      painter.paint(canvas, offset);
    }
  }

  @override
  bool get clip => false;
}

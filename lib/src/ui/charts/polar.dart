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

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/axes/axes.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/ticks.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/ui/axis_painter.dart';
import 'package:rubin_chart/src/ui/chart.dart';
import 'package:rubin_chart/src/ui/charts/scatter.dart';
import 'package:rubin_chart/src/utils/utils.dart';

/// Conversion factor from degrees to radians.
const degToRadians = math.pi / 180;

/// Conversion factor from radians to degrees.
const radiansToDeg = 1 / degToRadians;

/// A set of axes for a polar chart.
class PolarChartAxes extends ChartAxes {
  /// The ID of the radial axis.
  late final AxisId radialAxisId;

  /// The ID of the angular axis.
  late final AxisId angularAxisId;

  /// The center of the chart.
  Offset center = const Offset(10, 10);

  /// The scale of the x-axis (for zooming in/out).
  double scaleX = 1.0;

  /// The scale of the y-axis (for zooming in/out).
  double scaleY = 1.0;

  PolarChartAxes({required super.axes}) {
    // Extract the radial and angular axes from the map of axes.
    AxisId? radialAxisId;
    AxisId? angularAxisId;
    for (AxisId axisId in axes.keys) {
      AxisLocation location = axes[axisId]!.info.axisId.location;
      if (location == AxisLocation.radial) {
        radialAxisId = axisId;
      } else if (location == AxisLocation.angular) {
        angularAxisId = axisId;
      } else {
        throw AxesInitializationException("Unknown axis location: $location");
      }
    }
    this.radialAxisId = radialAxisId!;
    this.angularAxisId = angularAxisId!;
  }

  /// Create a new [PolarChartAxes] from a map of axes.
  static PolarChartAxes fromAxes({required Map<AxisId, ChartAxis> axes}) => PolarChartAxes(axes: axes);

  /// The radial axis.
  ChartAxis get radialAxis => axes[radialAxisId]!;

  /// The angular axis.
  ChartAxis get angularAxis => axes[angularAxisId]!;

  /// The Cartesian size of the axes.
  /// Polar plots are always square, so they have one size as opposed to separate width and height,
  /// where the size is just twice the radial extent.
  Bounds<double> get _axisSize {
    double size = radialAxis.bounds.max - radialAxis.bounds.min;
    return Bounds<double>(-size, size);
  }

  @override
  Bounds<double> get xBounds => _axisSize;

  @override
  Bounds<double> get yBounds => _axisSize;

  /// Convert a pair of polar (r, theta) coordinates to Cartesian (x, y) coordinates.
  @override
  Offset doubleToLinear(List<double> data) {
    // Note the astronomy convention that theta = 0 is at the top of the plot
    // and increases clockwise.
    if (data.length != 2) {
      throw ChartInitializationException("Polar projection requires two coordinates, got ${data.length}");
    }
    double rMin = radialAxis.bounds.min.toDouble();
    double radius = radialAxis.info.isInverted ? radialAxis.bounds.max - (data[0] - rMin) : data[0] - rMin;
    double theta = data[1].toDouble();

    return Offset(
      radius * math.sin(theta * degToRadians),
      -radius * math.cos(theta * degToRadians),
    );
  }

  /// Convert a pair of Cartesian (x, y) coordinates to polar (r, theta) coordinates.
  @override
  List<double> doubleFromLinear(Offset cartesian) {
    double radius = math.sqrt(cartesian.dx * cartesian.dx + cartesian.dy * cartesian.dy);
    radius = radialAxis.info.isInverted
        ? radialAxis.bounds.max - radialAxis.bounds.min + radius
        : radius + radialAxis.bounds.min;
    double theta = math.atan2(cartesian.dx, -cartesian.dy) * radiansToDeg;
    return [radius, theta];
  }

  /// Convert x values into pixel values.
  @override
  double xLinearToPixel({required double x, required double chartWidth}) {
    double xMin = xBounds.min;
    double xMax = xBounds.max;
    return (x - xMin) / (xMax - xMin) * chartWidth * scaleX + center.dx;
  }

  /// Convert pixel x values into native x values.
  @override
  double xLinearFromPixel({required double px, required double chartWidth}) {
    double xMin = xBounds.min;
    double xMax = xBounds.max;
    return (px - center.dx) / (chartWidth * scaleX) * (xMax - xMin) + xMin;
  }

  /// Convert y values into pixel values.
  @override
  double yLinearToPixel({required double y, required double chartHeight}) {
    double yMin = yBounds.min;
    double yMax = yBounds.max;
    return (y - yMin) / (yMax - yMin) * chartHeight * scaleY + center.dy;
  }

  /// Convert pixel y values into native y values.
  @override
  double yLinearFromPixel({required double py, required double chartHeight}) {
    double yMin = yBounds.min;
    double yMax = yBounds.max;
    return (py - center.dy) / (chartHeight * scaleY) * (yMax - yMin) + yMin;
  }

  @override
  Rect get linearRect => Rect.fromPoints(
        Offset(xBounds.min, yBounds.min),
        Offset(xBounds.max, yBounds.max),
      );

  /// Translate the displayed axes by a given amount.
  @override
  void translate(Offset delta, Size chartSize) {
    center -= delta;
  }

  /// Scale the displayed axes by a given amount.
  @override
  void scale(double scaleX, double scaleY, Size chartSize) {
    Offset linearCenter = linearFromPixel(
      pixel: Offset(chartSize.width / 2, chartSize.height / 2),
      chartSize: chartSize,
    );
    double scale = math.max(scaleX, scaleY);
    this.scaleX *= scale;
    this.scaleY = this.scaleX;
    Offset newCenter = linearToPixel(linearCoords: linearCenter, chartSize: chartSize);
    center = center - newCenter + Offset(chartSize.width / 2, chartSize.height / 2);

    linearCenter = linearFromPixel(
      pixel: Offset(chartSize.width / 2, chartSize.height / 2),
      chartSize: chartSize,
    );
  }
}

/// Units used for the angular axis in a polar plot.
enum PolarUnits {
  /// Angular axis is in radians.
  radians,

  /// Angular axis is in degrees.
  degrees,
}

/// A class containing information about a polar scatter plot.
class PolarScatterPlotInfo extends ScatterPlotInfo {
  /// The units used for the angular axis.
  PolarUnits units;

  PolarScatterPlotInfo({
    required super.id,
    required super.allSeries,
    super.title,
    super.theme,
    super.legend,
    super.axisInfo,
    super.colorCycle,
    super.interiorAxisLabelLocation,
    super.flexX,
    super.flexY,
    super.cursorAction,
    this.units = PolarUnits.degrees,
  }) : super(xToYRatio: 1.0);

  @override
  Map<Object, ChartAxes> initializeAxes({required Set<Object> drillDownDataPoints}) {
    final Map<AxisId, ChartAxis> axes = {};
    ChartAxis? radialAxis;
    ChartAxis? angularAxis;
    for (MapEntry<AxisId, ChartAxisInfo> entry in axisInfo.entries) {
      ChartAxisInfo axisInfo = entry.value;
      if (entry.value.axisId.location == AxisLocation.radial) {
        Map<Series, AxisId> seriesMap = {};
        for (Series series in allSeries) {
          seriesMap[series] = axisInfo.axisId;
        }
        if (seriesMap.isEmpty) {
          return {};
        }
        radialAxis = initializeAxis(
          allSeries: seriesMap,
          theme: theme,
          axisInfo: axisInfo,
          drillDownDataPoints: drillDownDataPoints,
        );
        axes[entry.key] = radialAxis;
      } else if (entry.value.axisId.location == AxisLocation.angular) {
        // Always use the same set of tick labels for the angular axis.
        List<String> tickLabels = [];
        if (units == PolarUnits.radians) {
          tickLabels = ["0", "π/4", "π/2", "3π/4", "π", "5π/4", "3π/2", "7π/4", "2π"];
        } else {
          tickLabels = ["0°", "45°", "90°", "135°", "180°", "225°", "270°", "315°", "360°"];
        }
        if (axisInfo.isInverted) {
          tickLabels = tickLabels.reversed.toList();
        }

        Bounds<double> bounds = const Bounds<double>(0, 2 * math.pi);
        AxisTicks ticks = AxisTicks(
          bounds: bounds,
          majorTicks: List.generate(9, (index) => index * 45),
          minorTicks: [],
          tickLabels: tickLabels,
        );
        angularAxis = NumericalChartAxis(
          info: axisInfo,
          bounds: bounds,
          dataBounds: bounds,
          ticks: ticks,
          theme: theme,
        );
        axes[entry.key] = angularAxis;
      }
    }
    Object axesId = radialAxis!.info.axisId.axesId;
    return {axesId: PolarChartAxes.fromAxes(axes: axes)};
  }

  @override
  AxisPainter initializeAxesPainter({required Map<Object, ChartAxes> allAxes, required ChartTheme theme}) =>
      PolarAxisPainter.fromAxes(
        allAxes: allAxes,
        theme: theme,
      );
}

/// Paint the polar axes on a chart.
class PolarAxisPainter extends AxisPainter {
  PolarAxisPainter({
    required super.allAxes,
    required super.theme,
    super.tickPadding = 10,
  });

  /// Create a new [PolarAxisPainter] from a map of axes.
  static PolarAxisPainter fromAxes({
    required Map<Object, ChartAxes> allAxes,
    required ChartTheme theme,
    double tickPadding = 10,
  }) =>
      PolarAxisPainter(allAxes: allAxes, theme: theme, tickPadding: tickPadding);

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
    PolarChartAxes polarAxes = chartAxes as PolarChartAxes;
    ChartAxis rAxis = chartAxes.radialAxis;
    double rCenter = rAxis.info.isInverted ? rAxis.bounds.max + rAxis.bounds.min : rAxis.bounds.min;
    Offset center = chartAxes.project(data: [rCenter, 0], chartSize: size);
    Offset offset = Offset(margin.left + tickPadding, margin.top + tickPadding);
    center += offset;
    double radius = rAxis.info.isInverted ? rCenter - tick : tick - rCenter;
    radius = size.width / 2 / (rAxis.bounds.max - rAxis.bounds.min) * radius * polarAxes.scaleX;
    if (location == AxisLocation.radial) {
      canvas.drawCircle(center, radius, paint);
    } else if (location == AxisLocation.angular) {
      double maxTick = rAxis.info.isInverted
          ? rAxis.ticks.majorTicks.first.toDouble()
          : rAxis.ticks.majorTicks.last.toDouble();
      Offset edgePoint = chartAxes.project(data: [maxTick, tick], chartSize: size);
      canvas.drawLine(center, edgePoint + offset, paint);
    } else {
      throw UnimplementedError("Unknown axis location: $location");
    }
  }

  @override
  void drawTickLabels(Canvas canvas, Size size, ChartAxis axis, ChartAxes chartAxes) {
    AxisId axisId = axis.info.axisId;
    AxisTicks ticks = axis.ticks;
    Offset offset = Offset(margin.left + tickPadding, margin.top + tickPadding);
    for (int i = 0; i < ticks.majorTicks.length; i++) {
      TextPainter painter = tickLabelPainters[axisId]![i];
      Offset fullOffset = offset;
      double tick = ticks.majorTicks[i];

      if (axisId.location == AxisLocation.radial) {
        Offset topLeft = chartAxes.project(data: [tick, 0], chartSize: size);
        fullOffset += topLeft - Offset(0, painter.height);
      } else if (axisId.location == AxisLocation.angular) {
        ChartAxis rAxis = (allAxes.values.first as PolarChartAxes).radialAxis;
        double radius = rAxis.info.isInverted ? rAxis.ticks.majorTicks.first : rAxis.ticks.majorTicks.last;
        Offset topLeft = chartAxes.project(data: [radius, tick], chartSize: size);
        Offset preProjected = chartAxes.doubleToLinear([radius, tick]);
        CartesianQuadrant quadrant = getQuadrant(preProjected.dx, -preProjected.dy);
        fullOffset += topLeft;
        if (tick == 0) {
          fullOffset += Offset(-painter.width / 2, -painter.height);
        } else if (tick == 90) {
          fullOffset += Offset(0, -painter.height / 2);
        } else if (tick == 270) {
          fullOffset += Offset(-painter.width, -painter.height / 2);
        } else if (tick == 360) {
          continue;
        } else if (quadrant == CartesianQuadrant.first) {
          fullOffset += Offset(0, -painter.height);
        } else if (quadrant == CartesianQuadrant.second) {
          fullOffset += Offset(-painter.width, -painter.height);
        } else if (quadrant == CartesianQuadrant.third) {
          fullOffset += Offset(-painter.width, 0);
        }
      } else {
        throw UnimplementedError("Unknown axis location: ${axisId.location}");
      }

      painter.paint(canvas, fullOffset);
    }
  }

  @override
  bool get clip => true;
}

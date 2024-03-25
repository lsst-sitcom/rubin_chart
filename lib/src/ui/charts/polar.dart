import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/projection.dart';
import 'package:rubin_chart/src/models/axes/ticks.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/ui/axis_painter.dart';
import 'package:rubin_chart/src/ui/chart.dart';
import 'package:rubin_chart/src/ui/charts/scatter.dart';
import 'package:rubin_chart/src/utils/utils.dart';

class PolarChartAxes extends ChartAxes {
  PolarChartAxes({required super.axes});

  static PolarChartAxes fromAxes({required Map<AxisId, ChartAxis> axes}) => PolarChartAxes(axes: axes);

  ChartAxis get radialAxis {
    for (AxisId axisId in axes.keys) {
      AxisLocation location = axes[axisId]!.info.axisId.location;
      if (location == AxisLocation.radial) {
        return axes[axisId]!;
      }
    }
    throw Exception("No radial-axis found");
  }

  ChartAxis get angularAxis {
    for (AxisId axisId in axes.keys) {
      AxisLocation location = axes[axisId]!.info.axisId.location;
      if (location == AxisLocation.angular) {
        return axes[axisId]!;
      }
    }
    throw Exception("No y-axis found");
  }

  @override
  Bounds<double> get xBounds => Bounds<double>(-radialAxis.bounds.max, radialAxis.bounds.max);

  @override
  Bounds<double> get yBounds => Bounds<double>(-radialAxis.bounds.max, radialAxis.bounds.max);

  @override
  Polar2DProjection buildProjection(Size plotSize) =>
      Polar2DProjection.fromAxes(axes: axes.values.toList(), plotSize: plotSize);
}

enum PolarUnits {
  radians,
  degrees,
}

class PolarScatterPlotInfo extends ScatterPlotInfo {
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
    this.units = PolarUnits.degrees,
  }) : super(xToYRatio: 1.0);

  @override
  Map<Object, ChartAxes> initializeAxes() {
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
        radialAxis = initializeAxis(allSeries: seriesMap, theme: theme, axisInfo: axisInfo);
        axes[entry.key] = radialAxis;
      } else if (entry.value.axisId.location == AxisLocation.angular) {
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
          //stepSize: math.pi / 4,
          stepSize: NiceNumber(0, 1, 1),
          bounds: bounds,
          ticks: List.generate(9, (index) => index * 45),
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

class PolarAxisPainter extends AxisPainter {
  PolarAxisPainter({
    required super.allAxes,
    required super.theme,
    super.tickPadding = 10,
  });

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
    Projection projection,
    Paint paint,
  ) {
    ChartAxis rAxis = (allAxes.values.first as PolarChartAxes).radialAxis;
    double rCenter = rAxis.info.isInverted ? rAxis.bounds.max + rAxis.bounds.min : rAxis.bounds.min;
    Offset center = projection.project([rCenter, 0]);
    Offset offset = Offset(margin.left + tickPadding, margin.top + tickPadding);
    center += offset;
    double radius = rAxis.info.isInverted ? rCenter - tick : tick - rCenter;
    radius = projection.xTransform.scale * radius;
    if (location == AxisLocation.radial) {
      canvas.drawCircle(center, radius, paint);
    } else if (location == AxisLocation.angular) {
      double maxTick =
          rAxis.info.isInverted ? rAxis.ticks.ticks.first.toDouble() : rAxis.ticks.ticks.last.toDouble();
      Offset edgePoint = projection.project([maxTick, tick]);
      canvas.drawLine(center, edgePoint + offset, paint);
    } else {
      throw UnimplementedError("Unknown axis location: $location");
    }
  }

  @override
  void drawTickLabels(Canvas canvas, Size size, ChartAxis axis, Projection projection) {
    AxisId axisId = axis.info.axisId;
    AxisTicks ticks = axis.ticks;
    Offset offset = Offset(margin.left + tickPadding, margin.top + tickPadding);
    for (int i = 0; i < ticks.ticks.length; i++) {
      TextPainter painter = tickLabelPainters[axisId]![i];
      Offset fullOffset = offset;
      double tick = ticks.ticks[i];

      if (axisId.location == AxisLocation.radial) {
        Offset topLeft = projection.project([tick, 0]);
        fullOffset += topLeft - Offset(0, painter.height);
      } else if (axisId.location == AxisLocation.angular) {
        ChartAxis rAxis = (allAxes.values.first as PolarChartAxes).radialAxis;
        double radius = rAxis.info.isInverted ? rAxis.ticks.ticks.first : rAxis.ticks.ticks.last;
        Offset topLeft = projection.project([radius, tick]);
        Offset preProjected = projection.map([radius, tick]);
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
}

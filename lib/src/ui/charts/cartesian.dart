import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/projection.dart';
import 'package:rubin_chart/src/models/axes/ticks.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/ui/axis_painter.dart';
import 'package:rubin_chart/src/ui/charts/scatter.dart';
import 'package:rubin_chart/src/utils/utils.dart';

class CartesianChartAxes extends ChartAxes {
  CartesianChartAxes({required super.axes});

  static CartesianChartAxes fromAxes({required Map<AxisId, ChartAxis> axes}) =>
      CartesianChartAxes(axes: axes);

  ChartAxis get xAxis {
    for (AxisId axisId in axes.keys) {
      AxisLocation location = axes[axisId]!.info.axisId.location;
      if (location == AxisLocation.bottom || location == AxisLocation.top) {
        return axes[axisId]!;
      }
    }
    throw Exception("No x-axis found");
  }

  ChartAxis get yAxis {
    for (AxisId axisId in axes.keys) {
      AxisLocation location = axes[axisId]!.info.axisId.location;
      if (location == AxisLocation.left || location == AxisLocation.right) {
        return axes[axisId]!;
      }
    }
    throw Exception("No y-axis found");
  }

  @override
  Bounds<double> get xBounds => xAxis.bounds;

  @override
  Bounds<double> get yBounds => yAxis.bounds;

  @override
  void updateProjection(Size plotSize) {
    projection = CartesianProjection.fromAxes(axes: axes.values.toList(), plotSize: plotSize);
  }
}

class CartesianScatterPlotInfo extends ScatterPlotInfo {
  CartesianScatterPlotInfo({
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
    super.xToYRatio,
  });

  @override
  Map<Object, ChartAxes> initializeAxes() => initializeSimpleAxes(
        seriesList: allSeries,
        axisInfo: axisInfo,
        theme: theme,
        axesInitializer: CartesianChartAxes.fromAxes,
      );

  @override
  AxisPainter initializeAxesPainter({required Map<Object, ChartAxes> allAxes, required ChartTheme theme}) =>
      CartesianAxisPainter.fromAxes(
        allAxes: allAxes,
        theme: theme,
      );
}

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
    Projection projection,
    Paint paint,
  ) {
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

  @override
  void drawTickLabels(Canvas canvas, Size size, ChartAxis axis, Projection projection) {
    AxisId axisId = axis.info.axisId;
    AxisTicks ticks = axis.ticks;
    bool minIsBound = ticks.bounds.min == axis.bounds.min;
    bool maxIsBound = ticks.bounds.max == axis.bounds.max;

    for (int i = 0; i < ticks.ticks.length; i++) {
      if (i == 0 && minIsBound || i == ticks.ticks.length - 1 && maxIsBound) {
        continue;
      }
      TextPainter painter = tickLabelPainters[axisId]![i];
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
}

import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/axes/axes.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/ticks.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/ui/axis_painter.dart';
import 'package:rubin_chart/src/ui/chart.dart';
import 'package:rubin_chart/src/ui/charts/scatter.dart';
import 'package:rubin_chart/src/utils/utils.dart';

class CartesianChartAxes extends ChartAxes {
  late final AxisId xAxisId;
  late final AxisId yAxisId;

  CartesianChartAxes({required super.axes}) {
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

  static CartesianChartAxes fromAxes({required Map<AxisId, ChartAxis> axes}) =>
      CartesianChartAxes(axes: axes);

  ChartAxis get xAxis => axes[xAxisId]!;

  ChartAxis get yAxis => axes[yAxisId]!;

  @override
  Bounds<double> get xBounds => xAxis.bounds;

  @override
  Bounds<double> get yBounds => yAxis.bounds;

  /// Return an [Offset] from a pair of [double] x, y coordinates.
  @override
  Offset doubleToLinear(List<double> data) {
    if (data.length != 2) {
      throw ChartInitializationException("Cartesian projection requires two coordinates, got ${data.length}");
    }
    return Offset(data[0], data[1]);
  }

  /// Return a pair of [double] x, y coordinates from an [Offset].
  @override
  List<double> doubleFromLinear(Offset cartesian) => [cartesian.dx, cartesian.dy];

  /// Convert x values into pixel values.
  @override
  double xToPixel({required double x, required double chartWidth}) {
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
  double xFromPixel({required double px, required double chartWidth}) {
    if (xAxis.info.isInverted) {
      px = chartWidth - px;
    }
    double xMin = xBounds.min;
    double xMax = xBounds.max;
    return px / chartWidth * (xMax - xMin) + xMin;
  }

  /// Convert y values into pixel values.
  @override
  double yToPixel({required double y, required double chartHeight}) {
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
  double yFromPixel({required double py, required double chartHeight}) {
    if (yAxis.info.isInverted) {
      py = chartHeight - py;
    }
    double yMin = yBounds.min;
    double yMax = yBounds.max;
    return py / chartHeight * (yMax - yMin) + yMin;
  }

  @override
  Rect get linearRect => Rect.fromPoints(
        doubleToLinear([xBounds.min, yBounds.min]),
        doubleToLinear([xBounds.max, yBounds.max]),
      );

  /// Translate the displayed axes by a given amount.
  @override
  void translate(double dx, double dy) {
    xAxis.translate(dx);
    yAxis.translate(dy);
  }

  /// Scale the displayed axes by a given amount.
  @override
  void scale(double scaleX, double scaleY) {
    xAxis.scale(scaleX);
    yAxis.scale(scaleY);
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
    Paint paint,
    ChartAxes chartAxes,
  ) {
    if (location == AxisLocation.left) {
      double y = chartAxes.yToPixel(y: tick, chartHeight: size.height);
      canvas.drawLine(Offset(margin.left + tickPadding, margin.top + tickPadding + y),
          Offset(margin.left + tickPadding + theme.tickLength, margin.top + tickPadding + y), paint);
    } else if (location == AxisLocation.bottom) {
      double x = chartAxes.xToPixel(x: tick, chartWidth: size.width);
      canvas.drawLine(
          Offset(margin.left + tickPadding + x, margin.top + tickPadding + size.height),
          Offset(margin.left + tickPadding + x, margin.top + tickPadding + size.height - theme.tickLength),
          paint);
    } else if (location == AxisLocation.right) {
      double y = chartAxes.yToPixel(y: tick, chartHeight: size.height);
      canvas.drawLine(
          Offset(margin.left + tickPadding + size.width, margin.top + tickPadding + y),
          Offset(margin.left + tickPadding + size.width - theme.tickLength, margin.top + tickPadding + y),
          paint);
    } else if (location == AxisLocation.top) {
      double x = chartAxes.xToPixel(x: tick, chartWidth: size.width);
      canvas.drawLine(Offset(margin.left + tickPadding + x, margin.top + tickPadding),
          Offset(margin.left + tickPadding + x, margin.top + tickPadding + theme.tickLength), paint);
    } else {
      throw UnimplementedError("Unknown axis location: $location");
    }
  }

  @override
  void drawTickLabels(Canvas canvas, Size size, ChartAxis axis, ChartAxes chartAxes) {
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
        double y = chartAxes.yToPixel(y: ticks.ticks[i], chartHeight: size.height);
        offset = Offset(margin.left - painter.width, y + margin.top + tickPadding - painter.height / 2);
      } else if (axisId.location == AxisLocation.bottom) {
        double x = chartAxes.xToPixel(x: ticks.ticks[i], chartWidth: size.width);
        offset = Offset(
            x + margin.left + tickPadding - painter.width / 2, margin.top + 2 * tickPadding + size.height);
      } else if (axisId.location == AxisLocation.right) {
        double y = chartAxes.yToPixel(y: ticks.ticks[i], chartHeight: size.height);
        offset = Offset(
            margin.left + 2 * tickPadding + size.width, y + margin.top + tickPadding - painter.height / 2);
      } else if (axisId.location == AxisLocation.top) {
        double x = chartAxes.xToPixel(x: ticks.ticks[i], chartWidth: size.width);
        offset = Offset(x + margin.left - painter.width / 2, 0);
      } else {
        throw UnimplementedError("Unknown axis location: ${axisId.location}");
      }

      painter.paint(canvas, offset);
    }
  }
}

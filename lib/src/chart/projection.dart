import 'dart:math';
import 'dart:ui';

import 'package:rubin_chart/src/chart/axis.dart';
import 'package:rubin_chart/src/core/utils.dart';


/// Conversion factor from degrees to radians.
const degToRadians = pi/180;
/// Conversion factor from radians to degrees.
const radiansToDeg = 1/degToRadians;


/// Transformation from [PlotAxis] coordinates to plot coordinates.
class PlotTransform {
  final double origin;
  final double scale;
  final double? invertSize;

  PlotTransform({
    required this.origin,
    required this.scale,
    this.invertSize,
  });

  /// Load a plot transformation for a given [PlotAxis].
  static PlotTransform fromAxis({
    required PlotAxis axis,
    required double plotSize,
    double? invertSize,
  }) {
    Bounds bounds = axis.plotBounds;
    //bounds = axis.tickBounds!;
    return PlotTransform(
      origin: bounds.min.toDouble(),
      scale: plotSize / bounds.range,
      invertSize: invertSize,
    );
  }

  /// Convert a number from the axis coordinates to the plot coordinates
  double map(num x){
    double result = (x - origin) * scale;
    if(invertSize != null){
      result = invertSize! - result;
    }
    return result;
  }

  /// Convert a number from plot coordinates to axes coordinates
  double inverse(double x){
    double result = x;
    if(invertSize != null){
      result = invertSize! - result;
    }
    result = result / scale + origin;
    return result;
  }

  /// Two [PlotTransform]s are equal when their origin and scale are the same.
  /// This is used by  eg. [TickMarkPainter] to check whether or not a repaint is necessary.
  @override
  bool operator ==(Object other) => other is PlotTransform && other.origin == origin && other.scale == scale;

  /// Overriding the [==] operator also requires overriding the [hashCode].
  @override
  int get hashCode => Object.hash(origin, scale);

  @override
  String toString() => "PlotTransform(origin=$origin, scale=$scale)";
}


/// A projection from the axis to the plot co\anvas.
abstract class Projection<T> {
  /// Transform from cartesian x to plot x.
  final PlotTransform xTransform;
  /// Transform from cartesian y to plot y.
  final PlotTransform yTransform;

  const Projection({
    required this.xTransform,
    required this.yTransform,
  });

  Point<double> project({
    required List<T> coordinates,
    required List<PlotAxis> axes,
  });
}


/// A 2D projection
mixin Projection2D implements Projection<num> {
  @override
  Point<double> project({
    required List<num> coordinates,
    required List<PlotAxis> axes,
  }){
    Point projection = map(coordinates[0].toDouble(), coordinates[1].toDouble());
    double x = xTransform.map(projection.x);
    double y = yTransform.map(projection.y);
    return Point(x, y);
  }

  Point map(double coord1, double coord2) => Point(coord1, coord2);
}


class Linear2DProjection extends Projection<num> with Projection2D {
  const Linear2DProjection({
    required super.xTransform,
    required super.yTransform,
  });

  static Linear2DProjection fromAxes({
    required PlotAxis xAxis,
    required PlotAxis yAxis,
    required Size plotSize,
  }){
    double? xInvertSize = xAxis.isInverted ? plotSize.width : null;
    double? yInvertSize = yAxis.isInverted ? plotSize.height : null;
    return Linear2DProjection(
      xTransform: PlotTransform.fromAxis(axis: xAxis, plotSize: plotSize.width, invertSize: xInvertSize),
      yTransform: PlotTransform.fromAxis(axis: yAxis, plotSize: plotSize.height, invertSize: yInvertSize),
    );
  }
}


class Polar2DProjection extends Projection<num> with Projection2D {
  const Polar2DProjection({
    required super.xTransform,
    required super.yTransform,
  });

  static Polar2DProjection fromAxes({
    required PlotAxis rAxis,
    required PlotAxis thetaAxis,
    required Size plotSize,
  }){
    // TODO: fix this
    //double rMax = rAxis.scaledBounds!.max;
    double rMax = 90;
    double x0 = -rMax;
    double y0 = -rMax;
    double xScale = plotSize.width / (2 * rMax);
    double yScale = plotSize.height / (2 * rMax);

    return Polar2DProjection(
      xTransform: PlotTransform(origin: x0, scale: xScale),
      yTransform: PlotTransform(origin: y0, scale: yScale),
    );
  }

  @override
  Point map(double coord1, double coord2) => Point(
    // TODO: fix this
    //coord1 * cos(coord2*degToRadians),
    //coord1 * sin(coord2*degToRadians),
    coord1 * sin(coord2*degToRadians),
    coord1 * cos(coord2*degToRadians),
  );
}

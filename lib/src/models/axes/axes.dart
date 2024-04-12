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
///
/// This module contains the [ChartAxes] class and related classes and functions
/// to build and manipulate axes for a chart.

import "dart:math" as math;

import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/utils/utils.dart';

/// An error occurred while creating or updating an axis.
class AxesInitializationException implements Exception {
  final String message;

  AxesInitializationException(this.message);

  @override
  String toString() => message;
}

/// A function used to initialize a set of axes.
typedef AxesInitializer = ChartAxes Function({required Map<AxisId, ChartAxis> axes});

/// A collection of axes for a chart.
/// The axes are stored in a map with their [AxisId] as the key and
/// can be cartesian (x, y), polar coordinates (radial, angular) or (in theory)
/// any other (potentially higher dimensional) coordinate system.
///
/// [ChatAxes] contain methods to convert between the data coordiantes,
/// which can be numbers or data times (for now), and various other interpretations.
/// All coordinates are first converted into double values in their native
/// coordinate system. Then they are converted into linear x,y coordinates.
/// Finally, they are converted into pixel coordinates that can be displayed on the screen.
///
/// To implement these conversion we have chosen the nomenclature [dataToDouble] and
/// [dataFromDouble] to convert between data and double values, making it clear that
/// the "double" values are downstream from the "data" values. The same goes for
/// [doubleToLinear] and [doubleFromLinear], which map to linear x and y coordinates
/// regardless of the input coordinate system, and [linearToPixel] and [linearFromPixel],
/// which map fro linear x,y coordinates to a coordinate system that fits in the
/// designated chart area on the screen.
abstract class ChartAxes {
  /// The axes of the chart.
  final Map<AxisId, ChartAxis> axes;

  ChartAxes({required this.axes});

  /// The number of dimensions of the chart.
  int get dimension => axes.length;

  /// Select an axis by its [AxisId].
  ChartAxis operator [](AxisId axisId) {
    if (!axes.containsKey(axisId)) {
      throw MissingAxisException("$axisId not contained in the axes.");
    }
    return axes[axisId]!;
  }

  /// Update the margin in an [AxisPainter] based on the size of the tick labels.
  EdgeInsets updateMargin(AxisId axisId, EdgeInsets margin, TextPainter painter) {
    if (axisId.location == AxisLocation.left) {
      return margin.copyWith(left: math.max(margin.left, painter.width));
    } else if (axisId.location == AxisLocation.right) {
      return margin.copyWith(right: math.max(margin.right, painter.width));
    } else if (axisId.location == AxisLocation.top) {
      return margin.copyWith(top: math.max(margin.top, painter.height));
    } else if (axisId.location == AxisLocation.bottom) {
      return margin.copyWith(bottom: math.max(margin.bottom, painter.height));
    } else if (axisId.location == AxisLocation.radial || axisId.location == AxisLocation.angular) {
      return margin;
    }
    throw AxisUpdateException("Axis location ${axisId.location} has not been implemented.");
  }

  @override
  String toString() => "ChartAxes($axes)";

  /// Get the bounds of the linear x-axis.
  Bounds<double> get xBounds;

  /// Get the bounds of the linear y-axis.
  Bounds<double> get yBounds;

  /// Get the bounds of the radial axis.
  Rect get linearRect;

  /// Convert series data coordinates into double values.
  List<double> dataToDouble(List<dynamic> data) {
    List<double> result = [];
    for (int i = 0; i < data.length; i++) {
      result.add(axes.values.toList()[i].toDouble(data[i]));
    }
    return result;
  }

  /// Convert double values into series data coordinates.
  List<dynamic> dataFromDouble(List<double> data) {
    List<dynamic> result = [];
    for (int i = 0; i < data.length; i++) {
      result.add(axes.values.toList()[i].fromDouble(data[i]));
    }
    return result;
  }

  /// Convert a list of double coordinates into (x,y) coordinates.
  Offset doubleToLinear(List<double> data);

  /// Convert (x,y) coordinates into a list of double coordinates.
  List<double> doubleFromLinear(Offset cartesian);

  /// Convert x values into pixel values.
  double xLinearToPixel({required double x, required double chartWidth});

  /// Convert pixel x values into native x values.
  double xLinearFromPixel({required double px, required double chartWidth});

  /// Convert y values into pixel values.
  double yLinearToPixel({required double y, required double chartHeight});

  /// Convert pixel y values into native y values.
  double yLinearFromPixel({required double py, required double chartHeight});

  /// Convert x and y values into pixel values.
  Offset linearToPixel({required Offset linearCoords, required Size chartSize}) => Offset(
      xLinearToPixel(x: linearCoords.dx, chartWidth: chartSize.width),
      yLinearToPixel(y: linearCoords.dy, chartHeight: chartSize.height));

  /// Convert pixel values into x and y values.
  Offset linearFromPixel({required Offset pixel, required Size chartSize}) => Offset(
      xLinearFromPixel(px: pixel.dx, chartWidth: chartSize.width),
      yLinearFromPixel(py: pixel.dy, chartHeight: chartSize.height));

  /// Project a list of data points onto the chart.
  Offset project({required List<dynamic> data, required Size chartSize}) =>
      linearToPixel(linearCoords: doubleToLinear(dataToDouble(data)), chartSize: chartSize);

  /// Convert series data coordinates into linear cartesian coordinates.
  Offset dataToLinear(List<dynamic> data) => doubleToLinear(dataToDouble(data));

  /// Convert linear cartesian coordinates into series data coordinates.
  List<dynamic> dataFromLinear(Offset cartesian) => dataFromDouble(doubleFromLinear(cartesian));

  /// Convert series data coordinates into pixel coordinates.
  Offset dataToPixel(List<dynamic> data, Size chartSize) =>
      linearToPixel(linearCoords: dataToLinear(data), chartSize: chartSize);

  /// Convert pixel coordinates into series data coordinates.
  List<dynamic> dataFromPixel(Offset pixel, Size chartSize) =>
      dataFromLinear(linearFromPixel(pixel: pixel, chartSize: chartSize));

  /// Convert double values into pixel values.
  Offset doubleToPixel(List<double> data, Size chartSize) =>
      linearToPixel(linearCoords: doubleToLinear(data), chartSize: chartSize);

  /// Convert pixel values into double values.
  List<double> doubleFromPixel(Offset pixel, Size chartSize) =>
      doubleFromLinear(linearFromPixel(pixel: pixel, chartSize: chartSize));

  /// Translate the displayed axes by a given pixel amounts.
  void translate(Offset delta, Size chartSize);

  /// Scale the displayed axes by a given amount.
  void scale(double scaleX, double scaleY, Size chartSize);
}

/// Initialize a set of plot axes from a list of [Series],
/// assuming a linear mapping and naming the axes from the series columns.
Map<AxisId, ChartAxisInfo> getAxisInfoFromSeries(SeriesList seriesList) {
  Map<AxisId, ChartAxisInfo> axesInfo = {};
  for (Series series in seriesList.values) {
    for (AxisId axisId in series.data.plotColumns.keys) {
      String label = series.data.plotColumns[axisId].toString();
      if (!axesInfo.containsKey(axisId)) {
        axesInfo[axisId] = ChartAxisInfo(
          label: label,
          axisId: axisId,
        );
      }
    }
  }
  return axesInfo;
}

/// Initialize a set of axes from a list of [Series], a [Theme],
/// and [ChartAxis] information.
Map<Object, ChartAxes> initializeSimpleAxes({
  required List<Series> seriesList,
  required AxesInitializer axesInitializer,
  required ChartTheme theme,
  required Map<AxisId, ChartAxisInfo> axisInfo,
  required Set<Object> drillDownDataPoints,
}) {
  // A map of all the axes in the [ChartAxes].
  final Map<AxisId, ChartAxis> axes = {};
  for (MapEntry<AxisId, ChartAxisInfo> entry in axisInfo.entries) {
    AxisId axisId = entry.key;
    Map<Series, AxisId> seriesForAxis = {};
    for (Series series in seriesList) {
      // Create a map between the series and the axis it is linked to.
      if (series.data.plotColumns.containsKey(axisId)) {
        seriesForAxis[series] = axisId;
      }
    }
    if (seriesForAxis.isEmpty) {
      throw AxisUpdateException("Axis $axisId has no series linked to it.");
    }
    // Initialize the axis using the available series data.
    axes[axisId] = initializeAxis(
        allSeries: seriesForAxis,
        theme: theme,
        axisInfo: entry.value,
        drillDownDataPoints: drillDownDataPoints);
  }
  // Create the [ChartAxes] from each set of axes that have been identified and initialized.
  final List<Object> axesIds = axes.keys.map((e) => e.axesId).toList();
  final Map<Object, ChartAxes> result = {};
  for (Object axesId in axesIds) {
    result[axesId] = axesInitializer(
      axes: Map.fromEntries(axes.entries.where((entry) => entry.key.axesId == axesId)),
    );
  }
  return result;
}

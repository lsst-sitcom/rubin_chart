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

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/axes/axes.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/ticks.dart';
import 'package:rubin_chart/src/models/marker.dart';
import 'package:rubin_chart/src/utils/utils.dart';

/// The different types of data than can be plotted.
enum ColumnDataType {
  /// The data is a number.
  number,

  /// The data is a string.
  string,

  /// The data is a date-time.
  dateTime,
}

/// An exception occured while converting data into dart types.
class DataConversionException implements Exception {
  DataConversionException(this.message);

  String? message;

  @override
  String toString() => "$runtimeType:\n\t$message";
}

BigInt _nextSeriesId = BigInt.zero;
BigInt _getNextSeriesId() {
  _nextSeriesId += BigInt.one;
  return _nextSeriesId;
}

/// A series that is displayed in a chart.
@immutable
class Series {
  /// Each chart has a unqiue ID for each series in the chart.
  final Object id;

  /// The name of the series.
  final String? _name;

  /// Settings to draw markers for the series.
  final Marker? marker;

  /// Settings to draw error bars for the series.
  final ErrorBars? errorBars;

  /// The data points in the series.
  final SeriesData data;

  Series({
    Object? id,
    String? name,
    this.marker,
    this.errorBars,
    required this.data,
  })  : id = id ?? _getNextSeriesId(),
        _name = name;

  static get nextId => _nextSeriesId;
  String get name => _name ?? "Series-$id";

  /// Create a copy of the series with new values.
  Series copyWith({
    Object? id,
    String? name,
    Marker? marker,
    ErrorBars? errorBars,
    SeriesData? data,
  }) =>
      Series(
        id: id ?? this.id,
        name: name ?? this.name,
        marker: marker ?? this.marker,
        errorBars: errorBars ?? this.errorBars,
        data: data ?? this.data,
      );

  Series copy() => copyWith();

  @override
  String toString() => "Series<${_name ?? id}>";

  /// The number of data points in the series.
  int get length => data.length;

  /// The dimensionality of the data.
  int get dimension => data.dimension;

  /// The ID of the [ChartAxes] that the series is plotted on.
  Object get axesId => data.plotColumns.keys.first.axesId;
}

/// A collection of data points.
/// The data points can be multidimensional, however
/// the [SeriesData] class must be able to convert
/// the data points into a collection of numbers that
/// can be projected onto a 2D plane.
@immutable
class SeriesData {
  /// The data organized by column, then dataId->data point pair.
  final Map<Object, Map<Object, dynamic>> data;

  /// The columns that are plotted (in order of x, y, z, etc.)
  final Map<AxisId, Object> plotColumns;

  /// The data types of the columns.
  final Map<Object, ColumnDataType> columnTypes;

  const SeriesData({
    required this.data,
    required this.plotColumns,
    required this.columnTypes,
  });

  /// The number of data points in the series.
  int get length => data.values.first.length;

  /// Create a [SeriesData] object from a list of data points.
  /// This is used to create the [SeriesData] instance with
  /// a map of string values to their plot coordinate along the axis.
  /// Also, since the bounds will be needed for the chart axes,
  /// the bounds for each chart column are calculated here.
  static SeriesData fromData({
    required Map<Object, List<dynamic>> data,
    required Map<AxisId, Object> plotColumns,
    List<Object>? dataIds,
  }) {
    // Check that all of the columns are the same length.
    final int length = data[plotColumns.values.first]!.length;

    if (!data.values.every((element) => element.length == length)) {
      throw DataConversionException("All columns must have the same length");
    }
    if (!plotColumns.keys.every((e) => e.axesId == plotColumns.keys.first.axesId)) {
      throw DataConversionException("All columns must have the same chart axes ID");
    }
    dataIds ??= List.generate(length, (index) => index);
    // Check the data IDs are the same length as the data (if provided).
    if (dataIds.length != length) {
      throw DataConversionException(
          "Data IDs must be the same length as the data, got ${dataIds.length} and $length respectively");
    }

    // Find the unique string values in all columns of strings.
    // If the user initialized a column as dynamic, check the first
    // value to see if it is a string.
    final Map<Object, Map<Object, dynamic>> dataColumns = {};
    final Map<Object, ColumnDataType> columnTypes = {};

    for (Object plotColumn in data.keys) {
      Map<Object, Object> column = {};
      for (int i = 0; i < length; i++) {
        if (!data.containsKey(plotColumn)) {
          throw DataConversionException("Column $plotColumn not found in data");
        }
        column[dataIds[i]] = data[plotColumn]![i];
      }
      dataColumns[plotColumn] = column;
      if (data[plotColumn]!.first is num) {
        columnTypes[plotColumn] = ColumnDataType.number;
      } else if (data[plotColumn]!.first is String) {
        columnTypes[plotColumn] = ColumnDataType.string;
      } else if (data[plotColumn]!.first is DateTime) {
        columnTypes[plotColumn] = ColumnDataType.dateTime;
      } else {
        throw DataConversionException("Unable to determine column type for $plotColumn");
      }
    }
    return SeriesData(data: dataColumns, plotColumns: plotColumns, columnTypes: columnTypes);
  }

  /// Calculate the dimensionality of the data.
  int get dimension => plotColumns.length;

  /// Get the data points for a row in the series in their native format.
  List<dynamic> getRow(Object dataId, Iterable<AxisId> axes) {
    List<dynamic> coordinates = [];
    for (AxisId axisId in axes) {
      coordinates.add(data[plotColumns[axisId]]![dataId]);
    }
    return coordinates;
  }

  /// Calculate the bounds of the data for a column.
  Bounds<double> calculateBounds(Object column, Set<Object> drillDownData) {
    List<dynamic> values;
    if (drillDownData.isEmpty) {
      values = data[column]!.values.toList();
    } else {
      values = data[column]!
          .entries
          .where((entry) => drillDownData.contains(entry.key))
          .map((entry) => entry.value)
          .toList();
    }

    if (values.first is num) {
      return Bounds.fromList(values.map((e) => (e as num).toDouble()).toList());
    } else if (values.first is DateTime) {
      // TODO: replace the code below with a simple conversion to unix time,
      // but for now axis does not support [DateTime] tick labels.
      return Bounds.fromList(values.map((e) => dateTimeToMjd(e as DateTime)).toList());
    } else {
      throw DataConversionException("Unable to calculate bounds for column $column");
    }
  }
}

/// A list of series to be displayed in a chart.
@immutable
class SeriesList {
  /// The series in the [SeriesList].
  final List<Series> values;

  /// The color cycle for the series.
  final List<Color> colorCycle;

  const SeriesList(this.values, this.colorCycle);

  /// Get the marker for a series.
  Marker getMarker(int index) {
    Color defaultColor = colorCycle[index % colorCycle.length];
    return values[index].marker ??
        Marker(
          color: defaultColor,
          edgeColor: defaultColor,
        );
  }

  Series operator [](int index) => values[index];

  int get length => values.length;
}

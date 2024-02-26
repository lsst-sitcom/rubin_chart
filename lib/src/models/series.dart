import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/marker.dart';
import 'package:rubin_chart/src/utils/utils.dart';

/// The different types of data than can be plotted.
enum ColumnDataType {
  number,
  string,
  datetime,
}

/// An exception occured while converting data into dart types.
class DataConversionException implements Exception {
  DataConversionException(this.message);

  String? message;

  @override
  String toString() => "$runtimeType:\n\t$message";
}

/// A series that is displayed in a chart.
@immutable
class Series {
  /// Each chart has a unqiue ID for each series in the chart.
  final BigInt id;

  /// The name of the series.
  final String? name;

  /// Settings to draw markers for the series.
  final Marker? marker;

  /// Settings to draw error bars for the series.
  final ErrorBars? errorBars;

  /// The data points in the series.
  final SeriesData data;

  /// The data ids of selected data points.
  final List<Object>? selectedDataPoints;

  const Series({
    required this.id,
    this.name,
    this.marker,
    this.errorBars,
    required this.data,
    this.selectedDataPoints,
  });

  Series copyWith({
    BigInt? id,
    String? name,
    Marker? marker,
    ErrorBars? errorBars,
    List<AxisId>? axisIds,
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
  String toString() => "Series<${name ?? id}>";

  int get length => data.length;

  int get dimension => data.dimension;

  Object get axesId => data.plotColumns.keys.first.axesId;
}

/// A collection of data points.
/// The data points can be multidimensional, however
/// the [SeriesData] class must be able to convert
/// the data points into a collection of numbers that
/// can be projected onto a 2D plane.
@immutable
class SeriesData {
  /// The columns that are plotted (in order of x, y, z, etc.)
  final Map<Object, Map<Object, dynamic>> data;
  final Map<AxisId, Object> plotColumns;

  const SeriesData._(this.data, this.plotColumns);

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
      throw DataConversionException("Data IDs must be the same length as the data");
    }

    // Find the unique string values in all columns of strings.
    // If the user initialized a column as dynamic, check the first
    // value to see if it is a string.
    final Map<Object, Map<Object, dynamic>> dataColumns = {};

    for (Object plotColumn in data.keys) {
      Map<Object, Object> column = {};
      for (int i = 0; i < length; i++) {
        if (!data.containsKey(plotColumn)) {
          throw DataConversionException("Column $plotColumn not found in data");
        }
        column[dataIds[i]] = data[plotColumn]![i];
      }
      dataColumns[plotColumn] = column;
    }
    return SeriesData._(dataColumns, plotColumns);
  }

  /// Calculate the dimensionality of the data.
  int get dimension => plotColumns.length;

  List<dynamic> getRow(int index) {
    List<dynamic> coordinates = [];
    for (Object column in plotColumns.values) {
      coordinates.add(data[column]!.values.toList()[index]);
    }
    return coordinates;
  }

  Bounds calculateBounds(Object column) {
    List<dynamic> values = data[column]!.values.toList();
    if (values.first is num) {
      return Bounds.fromList(values.map((e) => e as num).toList());
    } else {
      throw DataConversionException("Unable to calculate bounds for column $column");
    }
  }
}

@immutable
class SeriesList {
  final List<Series> values;
  final List<Color> colorCycle;

  const SeriesList(this.values, this.colorCycle);

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

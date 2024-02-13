import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
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
class Series<C, I> {
  /// Each chart has a unqiue ID for each series in the chart.
  final BigInt id;

  /// The name of the series.
  final String? name;

  /// Settings to draw markers for the series.
  final Marker? marker;

  /// Settings to draw error bars for the series.
  final ErrorBars? errorBars;

  /// The index of the axes that the series is plotted on.
  /// This will either be 0 (left y and bottom x) or 1 (right y and top x).
  final int axesIndex;

  /// The data points in the series.
  final SeriesData<C, I> data;

  /// The data ids of selected data points.
  final List<I>? selectedDataPoints;

  Series(
      {required this.id,
      this.name,
      this.marker,
      this.errorBars,
      this.axesIndex = 0,
      required this.data,
      this.selectedDataPoints})
      : assert([0, 1].contains(axesIndex));

  Series copyWith({
    BigInt? id,
    String? name,
    Marker? marker,
    ErrorBars? errorBars,
    int? axesIndex,
    SeriesData<C, I>? data,
  }) =>
      Series(
        id: id ?? this.id,
        name: name ?? this.name,
        marker: marker ?? this.marker,
        errorBars: errorBars ?? this.errorBars,
        axesIndex: axesIndex ?? this.axesIndex,
        data: data ?? this.data,
      );

  Series copy() => copyWith();

  @override
  String toString() => "Series<${name ?? id}>";

  int get length => data.length;

  int get dimension => data.dimension;
}

/// A collection of data points.
/// The data points can be multidimensional, however
/// the [SeriesData] class must be able to convert
/// the data points into a collection of numbers that
/// can be projected onto a 2D plane.
@immutable
class SeriesData<C, I> {
  /// The columns that are plotted (in order of x, y, z, etc.)
  final Map<C, Map<I, dynamic>> data;
  final List<C> plotColumns;

  const SeriesData._(this.data, this.plotColumns);

  /// The number of data points in the series.
  int get length => data.values.first.length;

  /// Create a [SeriesData] object from a list of data points.
  /// This is used to create the [SeriesData] instance with
  /// a map of string values to their plot coordinate along the axis.
  /// Also, since the bounds will be needed for the chart axes,
  /// the bounds for each chart column are calculated here.
  static SeriesData fromData<C, I>({
    required Map<C, List<dynamic>> data,
    required List<C> plotColumns,
    List<I>? dataIds,
  }) {
    // Check that all of the columns are the same length.
    final int length = data[plotColumns[0]]!.length;

    if (!data.values.every((element) => element.length == length)) {
      throw DataConversionException("All columns must have the same length");
    }
    dataIds ??= List.generate(length, (index) => index as I);
    // Check the data IDs are the same length as the data (if provided).
    if (dataIds.length != length) {
      throw DataConversionException("Data IDs must be the same length as the data");
    }

    // Find the unique string values in all columns of strings.
    // If the user initialized a column as dynamic, check the first
    // value to see if it is a string.
    final Map<C, Map<I, dynamic>> dataColumns = {};

    for (C plotColumn in data.keys) {
      Map<I, dynamic> column = {};
      for (int i = 0; i < length; i++) {
        column[dataIds[i]] = data[plotColumn]![i];
      }
      dataColumns[plotColumn] = column;
    }
    return SeriesData<C, I>._(dataColumns, plotColumns);
  }

  /// Calculate the dimensionality of the data.
  int get dimension => plotColumns.length;

  List<dynamic> getRow(int index) {
    List<dynamic> coordinates = [];
    for (C column in plotColumns) {
      coordinates.add(data[column]!.values.toList()[index]);
    }
    return coordinates;
  }

  Bounds calculateBounds(C column) {
    List<dynamic> values = data[column]!.values.toList();
    if (values.first is num) {
      return Bounds.fromList(values.map((e) => e as num).toList());
    } else {
      throw DataConversionException("Unable to calculate bounds for column $C");
    }
  }
}

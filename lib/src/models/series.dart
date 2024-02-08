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
class Series<T, U> {
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
  final SeriesData<T, U> data;

  /// The data ids of selected data points.
  final List<U>? selectedDataPoints;

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
    SeriesData? data,
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

  Bounds getBounds(T column) => data.columns[column]!.bounds;
}

/// A column of data in a [SeriesData] object.
@immutable
abstract class SeriesColumn<C, I, V> {
  /// The identifier of the column in the [DataSeries].
  final C column;

  /// The data in the column (keys are unique ids).
  final Map<I, V> data;

  /// The type of data in the column.
  final ColumnDataType dataType;

  /// The bounds of the double projection of the data.
  final Bounds bounds;

  const SeriesColumn._(this.column, this.data, this.bounds, {required this.dataType});

  /// The number of data points in the column.
  int get length => data.length;

  double toDouble(int index);
  V fromDouble(double x);
  List<double> toDoubles();
  List<V> fromDoubles(List<double> x);
}

class NumericalSeriesColumn<C, I> extends SeriesColumn<C, I, double> {
  const NumericalSeriesColumn._(super.column, super.data, super.bounds)
      : super._(dataType: ColumnDataType.number);

  static NumericalSeriesColumn<C, I> fromData<C, I>({
    required Map<I, double> data,
    required C plotColumn,
    List<I>? dataIds,
  }) {
    List<double> columnData = data.values.toList();
    double min = columnData.reduce((current, next) => current < next ? current : next);
    double max = columnData.reduce((current, next) => current > next ? current : next);
    Bounds bounds = Bounds(min, max);
    return NumericalSeriesColumn._(plotColumn, data, bounds);
  }

  @override
  double toDouble(int index) => toDoubles()[index];

  @override
  double fromDouble(double x) => x;

  @override
  List<double> toDoubles() => data.values.toList();

  @override
  List<double> fromDoubles(List<double> x) => x;
}

/// Get a map of unique values to their numerical index.
Map<String, double> _getUniqueValues(List<String> values) {
  List<String> uniqueValues = [];
  for (String value in values) {
    if (!uniqueValues.contains(value)) {
      uniqueValues.add(value);
    }
  }
  uniqueValues.sort();
  return uniqueValues.asMap().map((key, value) => MapEntry(value, key.toDouble()));
}

@immutable
class StringSeriesColumn<C, I> extends SeriesColumn<C, I, String> {
  /// Map strings to doubles
  final Map<String, double> uniqueValues;
  final Map<double, String> doubleToString;

  const StringSeriesColumn._(super.column, super.data, super.bounds, this.uniqueValues, this.doubleToString)
      : super._(dataType: ColumnDataType.string);

  static StringSeriesColumn<C, I> fromData<C, I>({
    required Map<I, String> data,
    required C plotColumn,
    List<I>? dataIds,
  }) {
    Map<String, double> uniqueValues = _getUniqueValues(data[plotColumn] as List<String>);
    List<double> columnData = data.values.map((e) => uniqueValues[e]!).toList();
    double min = columnData.reduce((current, next) => current < next ? current : next);
    double max = columnData.reduce((current, next) => current > next ? current : next);
    Bounds bounds = Bounds(min, max);
    Map<double, String> doubleToString = uniqueValues.map((key, value) => MapEntry(value, key));
    Map<I, String> dataIdsMap = {};
    for (int i = 0; i < dataIds!.length; i++) {
      dataIdsMap[dataIds[i]] = data[plotColumn]![i];
    }
    return StringSeriesColumn._(plotColumn, dataIdsMap, bounds, uniqueValues, doubleToString);
  }

  @override
  double toDouble(int index) => uniqueValues[data.values.toList()[index]]!;

  @override
  String fromDouble(double x) {
    String? value = doubleToString[x];
    if (value == null) {
      throw DataConversionException("Cannot convert $x to a string");
    }
    return value;
  }

  @override
  List<double> toDoubles() => data.values.map((e) => uniqueValues[e]!).toList();

  @override
  List<String> fromDoubles(List<double> x) {
    List<String> result = [];
    for (double number in x) {
      result.add(fromDouble(number));
    }
    return result;
  }
}

@immutable
class DateTimeSeriesColumn<C, I> extends SeriesColumn<C, I, DateTime> {
  const DateTimeSeriesColumn._(super.column, super.data, super.bounds)
      : super._(dataType: ColumnDataType.datetime);

  static DateTimeSeriesColumn<C, I> fromData<C, I>({
    required Map<I, DateTime> data,
    required C plotColumn,
    List<I>? dataIds,
  }) {
    List<double> columnData = data.values.map((e) => e.microsecondsSinceEpoch.toDouble()).toList();
    double min = columnData.reduce((current, next) => current < next ? current : next);
    double max = columnData.reduce((current, next) => current > next ? current : next);
    Bounds bounds = Bounds(min, max);
    return DateTimeSeriesColumn._(plotColumn, data, bounds);
  }

  @override
  double toDouble(int index) => data.values.toList()[index].microsecondsSinceEpoch.toDouble();

  @override
  DateTime fromDouble(double x) => DateTime.fromMicrosecondsSinceEpoch(x.toInt());

  @override
  List<double> toDoubles() => data.values.map((e) => e.microsecondsSinceEpoch.toDouble()).toList();

  @override
  List<DateTime> fromDoubles(List<double> x) =>
      x.map((e) => DateTime.fromMicrosecondsSinceEpoch(e.toInt())).toList();
}

/// A collection of data points.
/// The data points can be multidimensional, however
/// the [SeriesData] class must be able to convert
/// the data points into a collection of numbers that
/// can be projected onto a 2D plane.
@immutable
class SeriesData<C, I> {
  /// The columns that are plotted (in order of x, y, z, etc.)
  final Map<C, SeriesColumn<C, I, dynamic>> columns;

  final List<C> plotColumns;

  const SeriesData._(this.columns, this.plotColumns);

  /// The number of data points in the series.
  int get length => columns.values.first.length;

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
    final Map<C, SeriesColumn<C, I, dynamic>> dataColumns = {};
    for (C plotColumn in data.keys) {
      if (data[plotColumn] is List<String> ||
          (data[plotColumn].runtimeType == List && data[plotColumn]![0] is String)) {
        dataColumns[plotColumn] = StringSeriesColumn.fromData<C, I>(
            data: data.cast<I, String>(), plotColumn: plotColumn, dataIds: dataIds);
      } else if (data[plotColumn] is List<DateTime> ||
          (data[plotColumn].runtimeType == List && data[plotColumn]![0] is DateTime)) {
        dataColumns[plotColumn] = DateTimeSeriesColumn.fromData<C, I>(
            data: data.cast<I, DateTime>(), plotColumn: plotColumn, dataIds: dataIds);
      } else {
        dataColumns[plotColumn] = NumericalSeriesColumn.fromData<C, I>(
            data: data.cast<I, double>(), plotColumn: plotColumn, dataIds: dataIds);
      }
    }
    return SeriesData<C, I>._(dataColumns, plotColumns);
  }

  /// Calculate the numerical coordinate of a single data point.
  /// This should return a [List] of length [dimension].
  List<double> toCoordinates([int? index]) {
    if (index == null) {}
    List<double> result = [];
    for (SeriesColumn plotColumn in columns.values) {
      result.add(plotColumn.toDouble(index!));
    }
    return result;
  }

  /// Calculate the dimensionality of the data.
  int get dimension => columns.length;
}

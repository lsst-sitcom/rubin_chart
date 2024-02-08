import "dart:math" as math;
import "dart:collection";

import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/axes/mapping.dart';
import 'package:rubin_chart/src/models/axes/ticks.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/utils/utils.dart';

/// The orientation of a chart axis
enum AxisLocation {
  left,
  right,
  top,
  bottom,
  x3D,
  y3D,
  z3D,
  radial,
  angular,
}

/// The different types of data than can be plotted.
enum AxisDataType {
  number,
  string,
  datetTime,
}

/// Parameters needed to define an axis.
@immutable
abstract class ChartAxis<T> {
  /// The orientation of the axis.
  final AxisLocation location;

  /// Label of the axis in a chart.
  final String label;

  /// The max/min bounds of the axis displayed in a chart.
  final Bounds bounds;

  /// True if the displayed axis is inverted
  final bool isInverted;

  /// The mapping from the axis to the chart.
  /// This is usually linear but can be log, exponential, etc.
  final Mapping mapping;

  /// Tick marks for the axis.
  final AxisTicks ticks;

  final AxisDataType dataType;

  const ChartAxis._({
    required this.label,
    required this.bounds,
    required this.location,
    required this.ticks,
    required this.dataType,
    this.isInverted = false,
    this.mapping = const LinearMapping(),
  });

  double toDouble(T value);
  T fromDouble(double value);
}

@immutable
class NumericalChartAxis extends ChartAxis<double> {
  const NumericalChartAxis._({
    required super.label,
    required super.bounds,
    required super.location,
    required super.ticks,
    super.isInverted,
    super.mapping,
  }) : super._(
          dataType: AxisDataType.number,
        );

  static NumericalChartAxis fromData({
    required String label,
    required List<Bounds> data,
    required ChartTheme theme,
    required AxisLocation location,
    bool isInverted = false,
    mapping = const LinearMapping(),
    bool boundsFixed = false,
  }) {
    double min = data[0].min.toDouble();
    double max = data[0].max.toDouble();
    for (Bounds bounds in data) {
      min = math.min(min, bounds.min.toDouble());
      max = math.max(max, bounds.max.toDouble());
    }
    Bounds bounds = Bounds(min, max);
    AxisTicks ticks = AxisTicks.fromBounds(bounds, theme.minTicks, theme.maxTicks, true);

    return NumericalChartAxis._(
      label: label,
      bounds: bounds,
      location: location,
      ticks: ticks,
      isInverted: isInverted,
      mapping: mapping,
    );
  }

  NumericalChartAxis addData(
    List<Bounds> bounds,
    ChartTheme theme,
  ) =>
      fromData(
        label: label,
        data: [this.bounds, ...bounds],
        theme: theme,
        location: location,
        isInverted: isInverted,
        mapping: mapping,
      );

  @override
  double toDouble(double value) => value;

  @override
  double fromDouble(double value) => value;
}

@immutable
class StringChartAxis extends ChartAxis<String> {
  final List<String> uniqueValues;

  const StringChartAxis._({
    required super.label,
    required super.bounds,
    required super.location,
    required super.ticks,
    required this.uniqueValues,
    super.isInverted,
    super.mapping,
  }) : super._(
          dataType: AxisDataType.string,
        );

  static StringChartAxis fromData(
    String label,
    List<List<String>> data,
    ChartTheme theme,
    AxisLocation location, {
    bool isInverted = false,
    mapping = const LinearMapping(),
    bool boundsFixed = false,
  }) {
    Bounds bounds = Bounds(0, data.length.toDouble() - 1);
    List<String> uniqueValues = LinkedHashSet<String>.from(data.expand((e) => e)).toList();
    AxisTicks ticks = AxisTicks.fromStrings(uniqueValues);

    return StringChartAxis._(
      label: label,
      bounds: bounds,
      location: location,
      ticks: ticks,
      isInverted: isInverted,
      mapping: mapping,
      uniqueValues: uniqueValues,
    );
  }

  @override
  double toDouble(String value) => uniqueValues.indexOf(value).toDouble();

  @override
  String fromDouble(double value) => uniqueValues[value.toInt()];
}

@immutable
class DateTimeChartAxis extends ChartAxis<DateTime> {
  const DateTimeChartAxis._({
    required super.label,
    required super.bounds,
    required super.location,
    required super.ticks,
    super.isInverted,
    super.mapping,
  }) : super._(
          dataType: AxisDataType.datetTime,
        );

  static DateTimeChartAxis fromData({
    required String label,
    required List<DateTime> data,
    required ChartTheme theme,
    required AxisLocation location,
    bool isInverted = false,
    mapping = const LinearMapping(),
    bool boundsFixed = false,
  }) {
    DateTime min = data[0];
    DateTime max = data[0];
    for (DateTime date in data) {
      min = min.isBefore(date) ? min : date;
      max = max.isAfter(date) ? max : date;
    }
    Bounds bounds = Bounds(min.microsecondsSinceEpoch.toDouble(), max.microsecondsSinceEpoch.toDouble());
    AxisTicks ticks = AxisTicks.fromDateTime(bounds, theme.minTicks, theme.maxTicks, true);

    return DateTimeChartAxis._(
      label: label,
      bounds: bounds,
      location: location,
      ticks: ticks,
      isInverted: isInverted,
      mapping: mapping,
    );
  }

  @override
  double toDouble(DateTime value) => value.millisecondsSinceEpoch.toDouble();

  @override
  DateTime fromDouble(double value) => DateTime.fromMillisecondsSinceEpoch(value.toInt());
}

List<ChartAxis> initializeAxes2D<C, I>({required List<Series> seriesList, required ChartTheme theme}) {
  List<ChartAxis?> axes = [null, null, null, null];

  for (Series series in seriesList) {}

  for (Series series in seriesList) {
    int xIndex = 0;
    int yIndex = 1;
    AxisLocation xLocation = AxisLocation.bottom;
    AxisLocation yLocation = AxisLocation.left;
    if (series.axesIndex == 1) {
      xIndex = 2;
      yIndex = 3;
      xLocation = AxisLocation.right;
      yLocation = AxisLocation.top;
    }

    Bounds xBounds = series.getBounds(series.data.columns[0]);
    Bounds yBounds = series.getBounds(series.data.columns[1]);

    if (axes[xIndex] == null) {
      assert(axes[yIndex] == null, "UnexpectedError: Null y-axis for non-null x-axis.");
      C xColumn = series.data.plotColumns[0];
      C yColumn = series.data.plotColumns[1];

      String xLabel = series.data.columns[xColumn]!.column.toString();
      String yLabel = series.data.columns[yColumn]!.column.toString();
      AxisTicks xTicks =
          AxisTicks.fromColumn(series.data.columns[xColumn]!.column, theme.minTicks, theme.maxTicks, true);
      AxisTicks yTicks =
          AxisTicks.fromColumn(series.data.columns[yColumn]!.column, theme.minTicks, theme.maxTicks, true);

      axes[xIndex] = ChartAxis(
        label: xLabel,
        bounds: xTicks.bounds,
        location: xLocation,
        ticks: xTicks,
      );
      axes[yIndex] = ChartAxis(
        label: yLabel,
        bounds: yTicks.bounds,
        location: yLocation,
        ticks: yTicks,
      );
    } else {
      Bounds newXBounds = Bounds(
        math.min(xBounds.min, axes[xIndex]!.bounds.min),
        math.max(xBounds.max, axes[xIndex]!.bounds.max),
      );
      Bounds newYBounds = Bounds(
        math.min(yBounds.min, axes[yIndex]!.bounds.min),
        math.max(yBounds.max, axes[yIndex]!.bounds.max),
      );
      axes[xIndex] = axes[xIndex]!.copyWith(bounds: newXBounds);
      axes[yIndex] = axes[yIndex]!.copyWith(bounds: newYBounds);
    }
  }
  if (axes[2] == null && axes[3] == null) {
    axes = axes.sublist(0, 2);
  } else if (axes[2] == null || axes[3] == null) {
    throw "UnexpectedError: Null x-axis or y-axis for non-null x-axis or y-axis.";
  }

  return axes.map((e) => e!).toList();
}

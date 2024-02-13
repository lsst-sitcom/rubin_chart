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

@immutable
class ChartAxisInfo {
  final String label;
  final Mapping mapping;
  final bool isInverted;

  const ChartAxisInfo({
    required this.label,
    this.isInverted = false,
    this.mapping = const LinearMapping(),
  });
}

/// Parameters needed to define an axis.
@immutable
abstract class ChartAxis<T> {
  final ChartAxisInfo info;

  /// The orientation of the axis.
  final AxisLocation location;

  /// The max/min bounds of the axis displayed in a chart.
  final Bounds bounds;

  /// Tick marks for the axis.
  final AxisTicks ticks;

  final AxisDataType dataType;

  final ChartTheme theme;

  const ChartAxis._({
    required this.info,
    required this.bounds,
    required this.location,
    required this.ticks,
    required this.dataType,
    required this.theme,
  });

  double toDouble(T value);
  T fromDouble(double value);

  ChartAxis translated(double delta);

  ChartAxis scaled(double scale);
}

@immutable
class NumericalChartAxis extends ChartAxis<double> {
  const NumericalChartAxis._({
    required super.info,
    required super.bounds,
    required super.location,
    required super.ticks,
    required super.theme,
  }) : super._(
          dataType: AxisDataType.number,
        );

  static NumericalChartAxis fromData({
    required ChartAxisInfo axisInfo,
    required List<Bounds> data,
    required ChartTheme theme,
    required AxisLocation location,
  }) {
    double min = data[0].min.toDouble();
    double max = data[0].max.toDouble();
    for (Bounds bounds in data) {
      min = math.min(min, bounds.min.toDouble());
      max = math.max(max, bounds.max.toDouble());
    }
    AxisTicks ticks = AxisTicks.fromBounds(Bounds(min, max), theme.minTicks, theme.maxTicks, true);
    min = math.min(min, ticks.bounds.min.toDouble());
    max = math.max(max, ticks.bounds.max.toDouble());

    return NumericalChartAxis._(
        bounds: Bounds(min, max), location: location, ticks: ticks, info: axisInfo, theme: theme);
  }

  NumericalChartAxis addData(
    List<Bounds> bounds,
    ChartTheme theme,
  ) =>
      fromData(
        axisInfo: info,
        data: [this.bounds, ...bounds],
        theme: theme,
        location: location,
      );

  @override
  double toDouble(double value) => value;

  @override
  double fromDouble(double value) => value;

  @override
  NumericalChartAxis translated(double delta) {
    double min = bounds.min + delta;
    double max = bounds.max + delta;
    AxisTicks ticks = AxisTicks.fromBounds(Bounds(min, max), theme.minTicks, theme.maxTicks, false);
    return NumericalChartAxis._(
        info: info, bounds: Bounds(min, max), location: location, ticks: ticks, theme: theme);
  }

  @override
  NumericalChartAxis scaled(double scale) {
    double min = bounds.min.toDouble();
    double max = bounds.max.toDouble();
    double midpoint = (min + max) / 2;
    double range = max - min;
    double delta = range / scale / 2;

    min = midpoint - delta;
    max = midpoint + delta;

    AxisTicks ticks = AxisTicks.fromBounds(Bounds(min, max), theme.minTicks, theme.maxTicks, false);
    return NumericalChartAxis._(
        info: info, bounds: Bounds(min, max), location: location, ticks: ticks, theme: theme);
  }
}

@immutable
class StringChartAxis extends ChartAxis<String> {
  final List<String> uniqueValues;

  const StringChartAxis._({
    required super.info,
    required super.bounds,
    required super.location,
    required super.ticks,
    required this.uniqueValues,
    required super.theme,
  }) : super._(
          dataType: AxisDataType.string,
        );

  static StringChartAxis fromData({
    required ChartAxisInfo axisInfo,
    required List<List<String>> data,
    required ChartTheme theme,
    required AxisLocation location,
  }) {
    Bounds bounds = Bounds(0, data.length.toDouble() - 1);
    List<String> uniqueValues = LinkedHashSet<String>.from(data.expand((e) => e)).toList();
    AxisTicks ticks = AxisTicks.fromStrings(uniqueValues);

    return StringChartAxis._(
      info: axisInfo,
      bounds: bounds,
      location: location,
      ticks: ticks,
      uniqueValues: uniqueValues,
      theme: theme,
    );
  }

  @override
  double toDouble(String value) => uniqueValues.indexOf(value).toDouble();

  @override
  String fromDouble(double value) => uniqueValues[value.toInt()];

  @override
  StringChartAxis translated(double delta) {
    double min = bounds.min + delta;
    double max = bounds.max + delta;
    return StringChartAxis._(
      info: info,
      bounds: Bounds(min, max),
      location: location,
      ticks: ticks,
      uniqueValues: uniqueValues,
      theme: theme,
    );
  }

  @override
  StringChartAxis scaled(double scale) {
    double min = bounds.min.toDouble();
    double max = bounds.max.toDouble();
    double midpoint = (min + max) / 2;
    double range = max - min;
    double delta = range / scale / 2;

    min = midpoint - delta;
    max = midpoint + delta;

    return StringChartAxis._(
      info: info,
      bounds: bounds,
      location: location,
      ticks: ticks,
      uniqueValues: uniqueValues,
      theme: theme,
    );
  }
}

@immutable
class DateTimeChartAxis extends ChartAxis<DateTime> {
  const DateTimeChartAxis._({
    required super.info,
    required super.bounds,
    required super.location,
    required super.ticks,
    required super.theme,
  }) : super._(
          dataType: AxisDataType.datetTime,
        );

  static DateTimeChartAxis fromData({
    required ChartAxisInfo axisInfo,
    required List<DateTime> data,
    required ChartTheme theme,
    required AxisLocation location,
  }) {
    DateTime min = data[0];
    DateTime max = data[0];
    for (DateTime date in data) {
      min = min.isBefore(date) ? min : date;
      max = max.isAfter(date) ? max : date;
    }
    Bounds bounds = Bounds(min.microsecondsSinceEpoch.toDouble(), max.microsecondsSinceEpoch.toDouble());
    AxisTicks ticks = AxisTicks.fromDateTime(min, max, theme.minTicks, theme.maxTicks, true);

    return DateTimeChartAxis._(
      info: axisInfo,
      bounds: bounds,
      location: location,
      ticks: ticks,
      theme: theme,
    );
  }

  @override
  double toDouble(DateTime value) => value.millisecondsSinceEpoch.toDouble();

  @override
  DateTime fromDouble(double value) => DateTime.fromMillisecondsSinceEpoch(value.toInt());

  @override
  DateTimeChartAxis translated(double delta) {
    throw UnimplementedError();
  }

  @override
  NumericalChartAxis scaled(double scale) {
    throw UnimplementedError();
  }
}

List<ChartAxis> initializeAxes2D<C, I>({required List<Series> seriesList, required ChartTheme theme}) {
  List<ChartAxis?> axes = [null, null, null, null];

  List<List<Series>?> axesSeries = [null, null, null, null];
  for (Series series in seriesList) {
    int xIndex = 0;
    int yIndex = 1;
    if (series.axesIndex == 1) {
      xIndex = 2;
      yIndex = 3;
    }

    if (axesSeries[xIndex] == null) {
      axesSeries[xIndex] = [series];
    } else {
      axesSeries[xIndex]!.add(series);
    }
    if (axesSeries[yIndex] == null) {
      axesSeries[yIndex] = [series];
    } else {
      axesSeries[yIndex]!.add(series);
    }
  }

  for (int i = 0; i < axes.length; i++) {
    List<Series>? axisSeries = axesSeries[i];
    if (axisSeries != null) {
      AxisLocation location = i == 0
          ? AxisLocation.bottom
          : i == 1
              ? AxisLocation.left
              : i == 2
                  ? AxisLocation.right
                  : AxisLocation.top;
      Series series = axisSeries[0];

      ChartAxisInfo axisInfo = ChartAxisInfo(label: series.data.plotColumns[i]!.toString());
      dynamic data = series.data.data[series.data.plotColumns[i]]!.values.toList()[0];

      if (data is double) {
        axes[i] = NumericalChartAxis.fromData(
          axisInfo: axisInfo,
          data: axisSeries.map((e) => e.data.calculateBounds(e.data.plotColumns[i])).toList(),
          theme: theme,
          location: location,
        );
      } else if (data is String) {
        axes[i] = StringChartAxis.fromData(
          axisInfo: axisInfo,
          data: axisSeries
              .map((e) => e.data.data[series.data.plotColumns[i]]!.values.map((e) => e.toString()).toList())
              .toList(),
          theme: theme,
          location: i.isEven ? AxisLocation.bottom : AxisLocation.left,
        );
      } else if (data is DateTime) {
        throw UnimplementedError("DataTime data is not yet supported.");
      }
    }
  }

  if (axes[2] == null && axes[3] == null) {
    axes = axes.sublist(0, 2);
  } else if (axes[2] == null || axes[3] == null) {
    throw "UnexpectedError: Null x-axis or y-axis for non-null x-axis or y-axis.";
  }

  return axes.map((e) => e!).toList();
}

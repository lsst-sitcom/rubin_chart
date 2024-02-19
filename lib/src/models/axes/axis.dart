import "dart:math" as math;
import "dart:collection";

import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/axes/mapping.dart';
import 'package:rubin_chart/src/models/axes/projection.dart';
import 'package:rubin_chart/src/models/axes/ticks.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/utils/utils.dart';

/// An error occurred while creating or updating an axis.
class AxisUpdateException implements Exception {
  final String message;

  AxisUpdateException(this.message);

  @override
  String toString() => message;
}

/// Function to update an axis and rebuild a [State].
typedef AxisUpdate = void Function({Bounds? bounds, AxisTicks? ticks, ChartAxisInfo? info});

/// Controller for a set of axes.
/// This class is used to sync axes that may be linked
/// in different charts.
class AxisController {
  late Bounds bounds;
  late AxisTicks ticks;
  late ChartAxisInfo info;

  AxisController({
    required this.bounds,
    required this.ticks,
    required this.info,
  });

  /// Observers list
  final List<AxisUpdate> _observers = [];

  /// Subscribe the observer.
  /// It will also (optionally) update the other observers with the
  /// properties of the new axis that was added.
  void subscribe(AxisUpdate observer) {
    _observers.add(observer);
  }

  /// Unsubscribe the observer.
  void unsubscribe(AxisUpdate observer) {
    _observers.remove(observer);
  }

  /// Notify the observers about the changes.
  void _notifyObservers() {
    for (AxisUpdate observer in _observers) {
      observer(bounds: bounds, ticks: ticks, info: info);
    }
  }

  /// Update the controller.
  void update({
    Bounds? bounds,
    AxisTicks? ticks,
    ChartAxisInfo? info,
  }) {
    if (bounds != null) {
      this.bounds = bounds;
    }
    if (ticks != null) {
      this.ticks = ticks;
    }
    if (info != null) {
      this.info = info;
    }
    _notifyObservers();
  }
}

/// An ID for a [ChartAxis] in a [ChartAxes].
class AxisId<T> {
  /// The location of the axis in a chart.
  final AxisLocation location;

  /// The id of the [ChartAxes] that contains this [ChartAxis].
  final T axesId;

  AxisId._(this.location, this.axesId);

  /// Create an [AxisId] from a location and (optional) chart ID.
  factory AxisId(AxisLocation location, [T? chartId]) {
    if (T == int || chartId == null) {
      chartId ??= 0 as T;
      return AxisId._(location, chartId as T);
    }
    return AxisId._(location, chartId);
  }

  @override
  bool operator ==(Object other) {
    if (other is AxisId) {
      return location == other.location && axesId == other.axesId;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(location, axesId);

  @override
  String toString() => "AxisId($location, $axesId)";
}

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
  final AxisLocation location;

  const ChartAxisInfo({
    required this.label,
    required this.location,
    this.isInverted = false,
    this.mapping = const LinearMapping(),
  });
}

/// Parameters needed to define an axis.
abstract class ChartAxis<T> {
  ChartAxisInfo _info;

  /// The max/min bounds of the axis displayed in a chart.
  Bounds _bounds;

  /// Tick marks for the axis.
  AxisTicks _ticks;

  final AxisDataType dataType;

  final ChartTheme theme;

  AxisController? controller;

  /// Whether to show the ticks on the axis.
  final bool showTicks;

  /// Whether to show the labels on the axis.
  final bool showLabels;

  ChartAxis._({
    required ChartAxisInfo info,
    required Bounds bounds,
    required AxisTicks ticks,
    required this.dataType,
    required this.theme,
    this.controller,
    this.showTicks = true,
    this.showLabels = true,
  })  : _info = info,
        _bounds = bounds,
        _ticks = ticks;

  double toDouble(T value);
  T fromDouble(double value);

  void translate(double delta) {
    _translate(delta);
    controller?.update(bounds: bounds, ticks: ticks);
  }

  void _translate(double delta);

  void scale(double scale) {
    _scale(scale);
    controller?.update(bounds: bounds, ticks: ticks);
  }

  void _scale(double scale);

  ChartAxisInfo get info => _info;

  Bounds get bounds => _bounds;

  AxisTicks get ticks => _ticks;

  void update({
    ChartAxisInfo? info,
    Bounds? bounds,
    AxisTicks? ticks,
    required State state,
  }) {
    if (info != null) {
      _info = info;
    }
    if (bounds != null) {
      _bounds = bounds;
    }
    if (ticks != null) {
      _ticks = ticks;
    }
  }
}

class NumericalChartAxis extends ChartAxis<double> {
  NumericalChartAxis._({
    required super.info,
    required super.bounds,
    required super.ticks,
    required super.theme,
    super.showLabels = true,
    super.showTicks = true,
  }) : super._(
          dataType: AxisDataType.number,
        );

  static NumericalChartAxis fromData({
    required ChartAxisInfo axisInfo,
    required List<Bounds> data,
    required ChartTheme theme,
    bool showTicks = true,
    bool showLabels = true,
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
        bounds: Bounds(min, max),
        ticks: ticks,
        info: axisInfo,
        theme: theme,
        showTicks: showTicks,
        showLabels: showLabels);
  }

  NumericalChartAxis addData(
    List<Bounds> bounds,
    ChartTheme theme,
  ) =>
      fromData(
        axisInfo: info,
        data: [this.bounds, ...bounds],
        theme: theme,
      );

  @override
  double toDouble(double value) => value;

  @override
  double fromDouble(double value) => value;

  @override
  void _translate(double delta) {
    double min = bounds.min + delta;
    double max = bounds.max + delta;
    _bounds = Bounds(min, max);
    _ticks = AxisTicks.fromBounds(Bounds(min, max), theme.minTicks, theme.maxTicks, false);
  }

  @override
  void _scale(double scale) {
    double min = bounds.min.toDouble();
    double max = bounds.max.toDouble();
    double midpoint = (min + max) / 2;
    double range = max - min;
    double delta = range / scale / 2;

    min = midpoint - delta;
    max = midpoint + delta;

    _ticks = AxisTicks.fromBounds(Bounds(min, max), theme.minTicks, theme.maxTicks, false);
    _bounds = Bounds(min, max);
  }
}

class StringChartAxis extends ChartAxis<String> {
  final List<String> uniqueValues;

  StringChartAxis._({
    required super.info,
    required super.bounds,
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
  }) {
    Bounds bounds = Bounds(0, data.length.toDouble() - 1);
    List<String> uniqueValues = LinkedHashSet<String>.from(data.expand((e) => e)).toList();
    AxisTicks ticks = AxisTicks.fromStrings(uniqueValues);

    return StringChartAxis._(
      info: axisInfo,
      bounds: bounds,
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
  void _translate(double delta) {
    double min = bounds.min + delta;
    double max = bounds.max + delta;

    _bounds = Bounds(min, max);
  }

  @override
  void _scale(double scale) {
    double min = bounds.min.toDouble();
    double max = bounds.max.toDouble();
    double midpoint = (min + max) / 2;
    double range = max - min;
    double delta = range / scale / 2;

    min = midpoint - delta;
    max = midpoint + delta;

    _bounds = Bounds(min, max);
  }
}

class DateTimeChartAxis extends ChartAxis<DateTime> {
  DateTimeChartAxis._({
    required super.info,
    required super.bounds,
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
      ticks: ticks,
      theme: theme,
    );
  }

  @override
  double toDouble(DateTime value) => value.millisecondsSinceEpoch.toDouble();

  @override
  DateTime fromDouble(double value) => DateTime.fromMillisecondsSinceEpoch(value.toInt());

  @override
  void _translate(double delta) {
    throw UnimplementedError();
  }

  @override
  void _scale(double scale) {
    throw UnimplementedError();
  }
}

class MissingAxisException implements Exception {
  final String message;

  MissingAxisException(this.message);

  @override
  String toString() => message;
}

/// A collection of axes for a chart.
class ChartAxes<T> {
  /// The axes of the chart.
  final Map<AxisId<T>, ChartAxis> axes;

  /// The projection used to map the axes to pixel coordinates.
  final ProjectionInitializer projection;

  ChartAxes({required this.axes, required this.projection});

  /// The number of dimensions of the chart.
  int get dimension => axes.length;

  /// Select an axis by its [AxisId].
  ChartAxis operator [](AxisId<T> axisId) {
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
    }
    throw AxisUpdateException("Axis location ${axisId.location} has not been implemented.");
  }

  @override
  String toString() => "ChartAxes($axes)";
}

/// Initialize a set of plot axes from a list of [Series],
/// assuming a linear mapping and naming the axes from the series columns.
Map<AxisId<A>, ChartAxisInfo> getAxisInfoFromSeries<C, I, A>(SeriesList<C, I, A> seriesList) {
  Map<AxisId<A>, ChartAxisInfo> axesInfo = {};
  for (Series<C, I, A> series in seriesList.values) {
    for (AxisId<A> axisId in series.data.plotColumns.keys) {
      String label = series.data.plotColumns[axisId].toString();
      if (!axesInfo.containsKey(axisId)) {
        axesInfo[axisId] = ChartAxisInfo(
          label: label,
          location: axisId.location,
        );
      }
    }
  }
  return axesInfo;
}

ChartAxis initializeAxis<C, I>({
  required Map<Series, AxisId> allSeries,
  required ChartTheme theme,
  required ChartAxisInfo axisInfo,
}) {
  // Check that the map of allSeries is value
  if (!allSeries.entries.every((entry) => entry.key.data.plotColumns.containsKey(entry.value))) {
    throw AxisUpdateException("Not all series had a matching `AxisId` in the `allSeries` map.");
  }

  MapEntry<Series, AxisId> entry = allSeries.entries.first;

  Series series = entry.key;
  dynamic data = series.data.data[series.data.plotColumns[entry.value]]!.values.toList().first;
  if (data is double) {
    return NumericalChartAxis.fromData(
      axisInfo: axisInfo,
      data:
          allSeries.entries.map((e) => e.key.data.calculateBounds(e.key.data.plotColumns[e.value])).toList(),
      theme: theme,
    );
  } else if (data is String) {
    return StringChartAxis.fromData(
      axisInfo: axisInfo,
      data: allSeries.entries
          .map((e) =>
              e.key.data.data[e.key.data.plotColumns[e.value]]!.values.map((e) => e.toString()).toList())
          .toList(),
      theme: theme,
    );
  } else if (data is DateTime) {
    throw UnimplementedError("DataTime data is not yet supported.");
  }

  throw AxisUpdateException("Data type not supported.");
}

Map<A, ChartAxes> initializeSimpleAxes<A>({
  required List<Series> seriesList,
  required ProjectionInitializer projectionInitializer,
  required ChartTheme theme,
  required Map<AxisId<A>, ChartAxisInfo> axisInfo,
}) {
  final Map<AxisId<A>, ChartAxis> axes = {};
  for (MapEntry<AxisId<A>, ChartAxisInfo> entry in axisInfo.entries) {
    AxisId<A> axisId = entry.key;
    Map<Series, AxisId> seriesForAxis = {};
    for (Series series in seriesList) {
      if (series.data.plotColumns.containsKey(axisId)) {
        seriesForAxis[series] = axisId;
      }
    }
    if (seriesForAxis.isEmpty) {
      throw AxisUpdateException("Axis $axisId has no series linked to it.");
    }
    axes[axisId] = initializeAxis(allSeries: seriesForAxis, theme: theme, axisInfo: entry.value);
  }
  final List<A> axesIds = axes.keys.map((e) => e.axesId).toList();
  final Map<A, ChartAxes> result = {};
  for (A axesId in axesIds) {
    result[axesId] = ChartAxes(
      axes: Map.fromEntries(axes.entries.where((entry) => entry.key.axesId == axesId)),
      projection: projectionInitializer,
    );
  }
  return result;
}

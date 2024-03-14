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

/// Callback when an axis label is tapped.
typedef TapAxisCallback = void Function(int axisIndex);

/// Function to update an axis and rebuild a [State].
typedef AxisUpdate = void Function({Bounds? bounds, AxisTicks? ticks, ChartAxisInfo? info});

/// Controller for a set of axes.
/// This class is used to sync axes that may be linked
/// in different charts.
class AxisController {
  Bounds bounds;
  AxisTicks ticks;
  Bounds? maxBounds;

  AxisController({required this.bounds, required this.ticks, this.maxBounds});

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
      observer(bounds: bounds, ticks: ticks);
    }
  }

  /// Update the maximum bounds of the axis with the intersection of the current bounds.
  void updateMaxBoundsIntersection(Bounds bounds) {
    if (maxBounds != null) {
      num min = math.max(bounds.min, maxBounds!.min);
      num max = math.min(bounds.max, maxBounds!.max);
      this.bounds = Bounds(min, max);
    } else {
      maxBounds = bounds;
    }
  }

  /// Update the maximum bounds of the axis with the union of the current bounds.
  void updateMaxBoundsUnion(Bounds bounds) {
    if (maxBounds != null) {
      num min = math.min(bounds.min, maxBounds!.min);
      num max = math.max(bounds.max, maxBounds!.max);
      this.bounds = Bounds(min, max);
    } else {
      maxBounds = bounds;
    }
  }

  /// Update the controller.
  void update({
    Bounds? bounds,
    AxisTicks? ticks,
  }) {
    if (bounds != null) {
      num min = bounds.min;
      num max = bounds.max;
      if (maxBounds != null) {
        min = math.max(min, maxBounds!.min);
        max = math.min(max, maxBounds!.max);
      }
      this.bounds = Bounds(min, max);
    }
    if (ticks != null) {
      this.ticks = ticks;
    }
    _notifyObservers();
  }
}

/// An ID for a [ChartAxis] in a [ChartAxes].
class AxisId {
  /// The location of the axis in a chart.
  final AxisLocation location;

  /// The id of the [ChartAxes] that contains this [ChartAxis].
  final Object axesId;

  AxisId(this.location, [this.axesId = 0]);

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
  final AxisId axisId;

  const ChartAxisInfo({
    required this.label,
    required this.axisId,
    this.isInverted = false,
    this.mapping = const LinearMapping(),
  });
}

/// Parameters needed to define an axis.
abstract class ChartAxis<T extends Object> {
  ChartAxisInfo _info;

  /// The max/min bounds of the axis displayed in a chart.
  Bounds _bounds;

  /// Tick marks for the axis.
  AxisTicks _ticks;

  final AxisDataType dataType;

  final ChartTheme theme;

  AxisController? controller;

  /// Whether to show the ticks on the axis.
  bool showTicks;

  /// Whether to show the labels on the axis.
  bool showLabels;

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
class ChartAxes {
  /// The axes of the chart.
  final Map<AxisId, ChartAxis> axes;

  /// The projection used to map the axes to pixel coordinates.
  final ProjectionInitializer projection;

  ChartAxes({required this.axes, required this.projection});

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
    }
    throw AxisUpdateException("Axis location ${axisId.location} has not been implemented.");
  }

  @override
  String toString() => "ChartAxes($axes)";
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

ChartAxis initializeAxis({
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
          allSeries.entries.map((e) => e.key.data.calculateBounds(e.key.data.plotColumns[e.value]!)).toList(),
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

Map<Object, ChartAxes> initializeSimpleAxes({
  required List<Series> seriesList,
  required ProjectionInitializer projectionInitializer,
  required ChartTheme theme,
  required Map<AxisId, ChartAxisInfo> axisInfo,
}) {
  final Map<AxisId, ChartAxis> axes = {};
  for (MapEntry<AxisId, ChartAxisInfo> entry in axisInfo.entries) {
    AxisId axisId = entry.key;
    Map<Series, AxisId> seriesForAxis = {};
    for (Series series in seriesList) {
      if (series.data.plotColumns.containsKey(axisId)) {
        seriesForAxis[series] = axisId;
      }
      print("${series.name}, ${series.data.plotColumns.keys}");
    }
    if (seriesForAxis.isEmpty) {
      throw AxisUpdateException("Axis $axisId has no series linked to it.");
    }
    axes[axisId] = initializeAxis(allSeries: seriesForAxis, theme: theme, axisInfo: entry.value);
  }
  final List<Object> axesIds = axes.keys.map((e) => e.axesId).toList();
  final Map<Object, ChartAxes> result = {};
  for (Object axesId in axesIds) {
    result[axesId] = ChartAxes(
      axes: Map.fromEntries(axes.entries.where((entry) => entry.key.axesId == axesId)),
      projection: projectionInitializer,
    );
  }
  return result;
}

/// Initialize the basic information about all of the [ChartAxis] instances from a list of [Series].
Map<AxisId, ChartAxisInfo> axisInfoFromSeriesList(List<Series> seriesList) {
  Map<AxisId, ChartAxisInfo> axisInfo = {};
  for (Series series in seriesList) {
    if (!axisInfo.containsKey(series.axesId)) {
      List<ChartAxisInfo> axisInfos = [];
      for (MapEntry<AxisId, Object> entry in series.data.plotColumns.entries) {
        axisInfos.add(ChartAxisInfo(
          label: entry.value.toString(),
          axisId: entry.key,
        ));
      }
    }
  }
  return axisInfo;
}

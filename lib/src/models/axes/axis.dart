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

import "dart:math" as math;
import "dart:collection";

import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/axes/mapping.dart';
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
typedef TapAxisCallback = void Function({required AxisId axisId, required BuildContext context});

/// Function to update an axis and rebuild a [State].
typedef AxisUpdate = void Function({Bounds<double>? bounds, AxisTicks? ticks, ChartAxisInfo? info});

/// Controller for a set of axes.
/// This class is used to sync axes that may be linked
/// in different charts.
class AxisController {
  Bounds<double> bounds;
  AxisTicks ticks;

  AxisController({required this.bounds, required this.ticks});

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

  /// Update the controller.
  void update({
    Bounds<double>? bounds,
    AxisTicks? ticks,
  }) {
    bool updated = false;

    if (bounds != null) {
      double min = bounds.min;
      double max = bounds.max;
      this.bounds = Bounds(min, max);
      if (this.bounds != bounds) {
        updated = true;
      }
    }
    if (ticks != null) {
      this.ticks = ticks;
      updated = true;
    }
    if (updated) {
      _notifyObservers();
    }
  }
}

/// An ID for a [ChartAxis] in a [ChartAxes].
class AxisId {
  /// The location of the axis in a chart.
  final AxisLocation location;

  /// The id of the [ChartAxes] that contains this [ChartAxis].
  final Object axesId;

  AxisId(this.location, [this.axesId = 0]);

  /// Two [AxisId] instances are equal if their [location] and [axesId] are equal.
  @override
  bool operator ==(Object other) {
    if (other is AxisId) {
      return location == other.location && axesId == other.axesId;
    }
    return false;
  }

  /// The hash code of an [AxisId] is the hash of its [location] and [axesId].
  @override
  int get hashCode => Object.hash(location, axesId);

  @override
  String toString() => "AxisId($location, $axesId)";

  /// Convert the [AxisId] to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      "location": location.name,
      "axesId": axesId,
    };
  }

  /// Create an [AxisId] from a JSON object.
  factory AxisId.fromJson(Map<String, dynamic> json) {
    return AxisId(
      AxisLocation.values.firstWhere((e) => e.toString().split(".").last == json["location"]),
      json["axesId"],
    );
  }
}

/// The orientation of a chart axis
enum AxisLocation {
  /// The axis is on the left side of the chart.
  left,

  /// The axis is on the right side of the chart.
  right,

  /// The axis is on the top of the chart.
  top,

  /// The axis is on the bottom of the chart.
  bottom,

  /// The axis is the x-direction on a 3D chart (not implemented).
  x3D,

  /// The axis is the y-direction on a 3D chart (not implemented).
  y3D,

  /// The axis is the z-direction on a 3D chart (not implemented).
  z3D,

  /// The axis is the radial direction on a polar chart.
  radial,

  /// The axis is the angular direction on a polar chart.
  angular,

  /// The axis is the depth direction on a 3D chart (not implemented).
  color,
}

/// The orientation of a chart axis
enum AxisOrientation {
  /// The axis is horizontal.
  horizontal,

  /// The axis is vertical.
  vertical,

  /// The axis is radial.
  radial,

  /// The axis is angular.
  angular,
}

/// The different types of data than can be plotted.
enum AxisDataType {
  /// The data is a number.
  number,

  /// The data is a string.
  string,

  /// The data is a date-time.
  datetTime,
}

/// Information about a chart axis.
@immutable
class ChartAxisInfo {
  /// The label to display for the axis.
  final String label;

  /// The mapping to use for the axis.
  final Mapping mapping;

  /// Whether the axis is inverted.
  final bool isInverted;

  /// The [AxisId] of the axis.
  final AxisId axisId;

  /// Whether the axis is bounded.
  final bool isBounded;

  /// If [fixedBounds] is not null, the bounds of the axis will be fixed to these values.
  final Bounds<double>? fixedBounds;

  const ChartAxisInfo({
    required this.label,
    required this.axisId,
    this.isInverted = false,
    this.mapping = const LinearMapping(),
    this.isBounded = true,
    this.fixedBounds,
  });

  ChartAxisInfo copyWith({
    String? label,
    Mapping? mapping,
    bool? isInverted,
    AxisId? axisId,
    bool? isBounded,
    Bounds<double>? fixedBounds,
  }) {
    return ChartAxisInfo(
      label: label ?? this.label,
      mapping: mapping ?? this.mapping,
      isInverted: isInverted ?? this.isInverted,
      axisId: axisId ?? this.axisId,
      isBounded: isBounded ?? this.isBounded,
      fixedBounds: fixedBounds ?? this.fixedBounds,
    );
  }

  /// Whether the axis has fixed bounds.
  bool get isFixed => fixedBounds != null;

  /// Convert the [ChartAxisInfo] to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      "label": label,
      "mapping": mapping.toJson(),
      "isInverted": isInverted,
      "axisId": axisId.toJson(),
      "isBounded": isBounded,
      "fixedBounds": fixedBounds?.toJson(),
    };
  }

  /// Create a [ChartAxisInfo] from a JSON object.
  factory ChartAxisInfo.fromJson(Map<String, dynamic> json) {
    return ChartAxisInfo(
      label: json["label"],
      mapping: Mapping.fromJson(json["mapping"]),
      isInverted: json["isInverted"],
      axisId: AxisId.fromJson(json["axisId"]),
      isBounded: json["isBounded"],
      fixedBounds: json["fixedBounds"] != null ? Bounds.fromJson<double>(json["fixedBounds"]) : null,
    );
  }
}

/// Parameters needed to define an axis.
abstract class ChartAxis<T extends Object> {
  ChartAxisInfo _info;

  /// The max/min bounds of the axis displayed in a chart.
  Bounds<double> _bounds;

  /// The bounds of the data.
  /// This might not be the same as the total [bounds],
  /// since the axis may be zoomed in or translated.
  Bounds<double> dataBounds;

  /// Tick marks for the axis.
  AxisTicks _ticks;

  /// The data type of the axis.
  final AxisDataType dataType;

  /// The theme of the chart.
  final ChartTheme theme;

  /// The controller for the axis.
  AxisController? controller;

  /// Whether to show the ticks on the axis.
  bool showTicks;

  /// Whether to show the labels on the axis.
  bool showLabels;

  ChartAxis._({
    required ChartAxisInfo info,
    required Bounds<double> bounds,
    required this.dataBounds,
    required AxisTicks ticks,
    required this.dataType,
    required this.theme,
    this.controller,
    this.showTicks = true,
    this.showLabels = true,
  })  : _info = info,
        _bounds = bounds,
        _ticks = ticks;

  /// Convert a value to a double.
  double toDouble(T value);

  /// Convert a double to a native coordinate value.
  T fromDouble(double value);

  /// Update the tick marks and adjust the bounds if necessary
  void updateTicksAndBounds(Bounds<double> bounds) {
    if (info.isFixed) {
      return;
    }
    _ticks = _updateTicks(bounds);

    // Grow the bounds to fit the ticks, if necessary
    double min = math.min(bounds.min, ticks.bounds.min.toDouble());
    double max = math.max(bounds.max, ticks.bounds.max.toDouble());

    bounds = Bounds(min, max);
    if (bounds != this.bounds) {
      _bounds = bounds;
      controller?.update(bounds: bounds, ticks: _ticks);
    }
  }

  /// Update the tick marks and adjust the bounds if necessary.
  AxisTicks _updateTicks(Bounds<double> bounds);

  /// Extract the info for the axis.
  ChartAxisInfo get info => _info;

  /// Extract the bounds for the axis.
  Bounds<double> get bounds => _bounds;

  /// Extract the ticks for the axis.
  AxisTicks get ticks => _ticks;

  /// Update the axis with new information,
  /// usually from an [AxisController].
  void update({
    ChartAxisInfo? info,
    Bounds<double>? bounds,
    AxisTicks? ticks,
    required State state,
  }) {
    if (this.info.isFixed) {
      return;
    }
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

/// An axis for plotting numerical data.
class NumericalChartAxis extends ChartAxis<double> {
  NumericalChartAxis({
    required super.info,
    required super.bounds,
    required super.dataBounds,
    required super.ticks,
    required super.theme,
    super.showLabels = true,
    super.showTicks = true,
  }) : super._(
          dataType: AxisDataType.number,
        );

  /// Create a [NumericalAxis] with fixed bounds.
  static fromFixedBounds({
    required ChartAxisInfo axisInfo,
    required Bounds<double> bounds,
    required ChartTheme theme,
    bool showTicks = true,
    bool showLabels = true,
  }) {
    AxisTicks ticks = AxisTicks.fromBounds(bounds, theme.minTicks, theme.maxTicks, false, axisInfo.mapping);
    return NumericalChartAxis(
      bounds: bounds,
      dataBounds: bounds,
      ticks: ticks,
      info: axisInfo,
      theme: theme,
      showTicks: showTicks,
      showLabels: showLabels,
    );
  }

  /// Create a [NumericalAxis] from a list of data.
  static NumericalChartAxis fromData({
    required ChartAxisInfo axisInfo,
    required List<List<double>> data,
    required ChartTheme theme,
    bool showTicks = true,
    bool showLabels = true,
  }) {
    if (axisInfo.isFixed) {
      return fromFixedBounds(
        axisInfo: axisInfo,
        bounds: axisInfo.fixedBounds!,
        theme: theme,
        showTicks: showTicks,
        showLabels: showLabels,
      );
    }
    List<Bounds<double>> bounds = [];
    for (List<num> row in data) {
      double min = row.first.toDouble();
      double max = row.first.toDouble();
      for (num value in row) {
        min = math.min(min, value.toDouble());
        max = math.max(max, value.toDouble());
      }
      bounds.add(Bounds(min, max));
    }
    return fromBounds(
      axisInfo: axisInfo,
      boundsList: bounds,
      theme: theme,
      showTicks: showTicks,
      showLabels: showLabels,
    );
  }

  /// Create a [NumericalAxis] from a list of bounds.
  static NumericalChartAxis fromBounds({
    required ChartAxisInfo axisInfo,
    required List<Bounds<double>> boundsList,
    required ChartTheme theme,
    bool showTicks = true,
    bool showLabels = true,
  }) {
    if (axisInfo.isFixed) {
      return fromFixedBounds(
        axisInfo: axisInfo,
        bounds: axisInfo.fixedBounds!,
        theme: theme,
        showTicks: showTicks,
        showLabels: showLabels,
      );
    }
    double min = boundsList[0].min.toDouble();
    double max = boundsList[0].max.toDouble();
    for (Bounds<double> bounds in boundsList) {
      min = math.min(min, bounds.min.toDouble());
      max = math.max(max, bounds.max.toDouble());
    }
    Bounds<double> dataBounds = Bounds(min, max);
    AxisTicks ticks =
        AxisTicks.fromBounds(dataBounds, theme.minTicks, theme.maxTicks, true, axisInfo.mapping);
    min = math.min(min, ticks.bounds.min.toDouble());
    max = math.max(max, ticks.bounds.max.toDouble());

    return NumericalChartAxis(
      bounds: Bounds(min, max),
      dataBounds: dataBounds,
      ticks: ticks,
      info: axisInfo,
      theme: theme,
      showTicks: showTicks,
      showLabels: showLabels,
    );
  }

  @override
  double toDouble(double value) => value;

  @override
  double fromDouble(double value) => value;

  @override
  AxisTicks _updateTicks(Bounds<double> bounds) {
    return AxisTicks.fromBounds(bounds, theme.minTicks, theme.maxTicks, false, info.mapping);
  }

  @override
  String toString() => "NumericalChartAxis<${info.axisId}: $_bounds>";
}

/// An axis for plotting string data.
/// Currently this is not supported or implemented,
/// but could be implemented with fairly minimal effort.
class StringChartAxis extends ChartAxis<String> {
  /// The unique [String] values in the data.
  final List<String> uniqueValues;

  StringChartAxis._({
    required super.info,
    required super.bounds,
    required super.dataBounds,
    required super.ticks,
    required this.uniqueValues,
    required super.theme,
  }) : super._(
          dataType: AxisDataType.string,
        );

  /// Create a [StringAxis] from a list of data.
  static StringChartAxis fromData({
    required ChartAxisInfo axisInfo,
    required List<List<String>> data,
    required ChartTheme theme,
  }) {
    double min = 0;
    double max = data.length.toDouble() - 1;
    List<String> uniqueValues = LinkedHashSet<String>.from(data.expand((e) => e)).toList();
    AxisTicks ticks = AxisTicks.fromStrings(uniqueValues);
    Bounds<double> dataBounds = Bounds(min, max);
    min = math.min(min, ticks.bounds.min.toDouble());
    max = math.max(max, ticks.bounds.max.toDouble());

    return StringChartAxis._(
      info: axisInfo,
      bounds: Bounds(min, max),
      dataBounds: dataBounds,
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
  AxisTicks _updateTicks(Bounds<double> bounds) {
    return _ticks;
  }
}

/// A chart axis for plotting dates and times.
/// Currently this is shows up as a Modified Julian Date (MJD),
/// since making "pretty" tick marks for a date-time is non-trivial
/// and it has been a low priority for us.
class DateTimeChartAxis extends ChartAxis<DateTime> {
  DateTimeChartAxis._({
    required super.info,
    required super.bounds,
    required super.dataBounds,
    required super.ticks,
    required super.theme,
  }) : super._(
          dataType: AxisDataType.datetTime,
        );

  /// Create a [DateTimeChartAxis] with fixed bounds.
  static fromFixedBounds({
    required ChartAxisInfo axisInfo,
    required Bounds<DateTime> bounds,
    required ChartTheme theme,
    bool showLabels = true,
    bool showTicks = true,
  }) {
    Bounds<double> doubleBounds = Bounds(dateTimeToMjd(bounds.min), dateTimeToMjd(bounds.max));
    AxisTicks ticks =
        AxisTicks.fromBounds(doubleBounds, theme.minTicks, theme.maxTicks, false, axisInfo.mapping);
    return DateTimeChartAxis._(
      info: axisInfo,
      bounds: doubleBounds,
      dataBounds: doubleBounds,
      ticks: ticks,
      theme: theme,
    );
  }

  /// Create a [DateTimeChartAxis] in the modified Dulian date
  /// (MJD) format from a list of date-times.
  static DateTimeChartAxis fromDataMjd({
    required ChartAxisInfo axisInfo,
    required List<List<DateTime>> data,
    required ChartTheme theme,
    bool showLabels = true,
    bool showTicks = true,
  }) {
    DateTime min = data.first.first;
    DateTime max = data.first.first;
    for (List<DateTime> dateList in data) {
      for (DateTime date in dateList) {
        min = min.isBefore(date) ? min : date;
        max = max.isAfter(date) ? max : date;
      }
    }
    double doubleMin = dateTimeToMjd(min);
    double doubleMax = dateTimeToMjd(max);
    Bounds<double> dataBounds = Bounds(doubleMin, doubleMax);
    AxisTicks ticks =
        AxisTicks.fromBounds(dataBounds, theme.minTicks, theme.maxTicks, true, axisInfo.mapping);
    doubleMin = math.min(doubleMin, ticks.bounds.min.toDouble());
    doubleMax = math.max(doubleMax, ticks.bounds.max.toDouble());
    Bounds<double> bounds = Bounds(doubleMin, doubleMax);

    return DateTimeChartAxis._(
      info: axisInfo,
      bounds: bounds,
      dataBounds: dataBounds,
      ticks: ticks,
      theme: theme,
    );
  }

  /// Create a [DateTimeChartAxis] from a list of date-times.
  /// For now this just implements the data-time as MJD.
  static DateTimeChartAxis fromData({
    required ChartAxisInfo axisInfo,
    required List<List<DateTime>> data,
    required ChartTheme theme,
    bool showLabels = true,
    bool showTicks = true,
  }) {
    // TODO: implement AxisTicks.fromDateTime and uncomment
    /*
    DateTime min = data.first.first;
    DateTime max = data.first.first;
    for (List<DateTime> dateList in data) {
      for (DateTime date in dateList) {
        min = min.isBefore(date) ? min : date;
        max = max.isAfter(date) ? max : date;
      }
    }
    Bounds<double> dataBounds = Bounds(
      min.millisecondsSinceEpoch.toDouble(),
      max.millisecondsSinceEpoch.toDouble(),
    );
    AxisTicks ticks = AxisTicks.fromDateTime(min, max, theme.minTicks, theme.maxTicks, true);
    double doubleMin = min.millisecondsSinceEpoch.toDouble();
    double doubleMax = max.millisecondsSinceEpoch.toDouble();
    doubleMin = math.min(doubleMin, ticks.bounds.min.toDouble());
    doubleMax = math.max(doubleMax, ticks.bounds.max.toDouble());
    Bounds<double> bounds = Bounds(doubleMin, doubleMax);

    return DateTimeChartAxis._(
      info: axisInfo,
      bounds: bounds,
      dataBounds: dataBounds,
      ticks: ticks,
      theme: theme,
    );*/
    return fromDataMjd(
      axisInfo: axisInfo,
      data: data,
      theme: theme,
      showLabels: showLabels,
      showTicks: showTicks,
    );
  }

  /// Create a [DateTimeChartAxis] from a list of bounds.
  /// For now this just implements the data-time as MJD.
  static DateTimeChartAxis fromBounds({
    required ChartAxisInfo axisInfo,
    required List<Bounds<double>> boundsList,
    required ChartTheme theme,
  }) {
    // TODO: implement AxisTicks.fromDateTime and uncomment
    /*double min = boundsList.first.min;
    double max = boundsList.first.max;
    for (Bounds<double> bounds in boundsList) {
      min = math.min(min, bounds.min);
      max = math.max(max, bounds.max);
    }
    Bounds<double> dataBounds = Bounds(min, max);
    DateTime minDate = DateTime.fromMillisecondsSinceEpoch(min.toInt());
    DateTime maxDate = DateTime.fromMillisecondsSinceEpoch(max.toInt());
    AxisTicks ticks = AxisTicks.fromDateTime(minDate, maxDate, theme.minTicks, theme.maxTicks, true);

    min = math.min(min, ticks.bounds.min.toDouble());
    max = math.max(max, ticks.bounds.max.toDouble());
    Bounds<double> bounds = Bounds(min, max);

    return DateTimeChartAxis._(
      info: axisInfo,
      bounds: bounds,
      dataBounds: dataBounds,
      ticks: ticks,
      theme: theme,
    );*/
    return fromDataMjd(
      axisInfo: axisInfo,
      data: boundsList.map((e) => [mjdToDateTime(e.min), mjdToDateTime(e.max)]).toList(),
      theme: theme,
    );
  }

  @override
  double toDouble(DateTime value) => dateTimeToMjd(value);

  @override
  DateTime fromDouble(double value) => mjdToDateTime(value);

  @override
  AxisTicks _updateTicks(Bounds<double> bounds) {
    // TODO: implement AxisTicks.fromDateTime and uncomment
    /*DateTime minDate = mjdToDateTime(bounds.min);
    DateTime maxDate = mjdToDateTime(bounds.max);
    return AxisTicks.fromDateTime(minDate, maxDate, theme.minTicks, theme.maxTicks, true);*/
    return AxisTicks.fromBounds(bounds, theme.minTicks, theme.maxTicks, false, info.mapping);
  }
}

/// An exception that is thrown when an axis is missing.
class MissingAxisException implements Exception {
  final String message;

  MissingAxisException(this.message);

  @override
  String toString() => message;
}

/// Initialize a [ChartAxis] from [Series] data, a [ChartTheme], and [ChartAxisInfo].
/// If [drillDownDataPoints] is not empty, the axis will be initialized with only the data points
/// that are in the set.
ChartAxis initializeAxis({
  required Map<Series, AxisId> allSeries,
  required ChartTheme theme,
  required ChartAxisInfo axisInfo,
  required Set<Object> drillDownDataPoints,
}) {
  // Check that the map of allSeries is value
  if (!allSeries.entries.every((entry) => entry.key.data.plotColumns.containsKey(entry.value))) {
    throw AxisUpdateException("Not all series had a matching `AxisId` in the `allSeries` map.");
  }

  MapEntry<Series, AxisId> entry = allSeries.entries.first;

  Series series = entry.key;
  List allData = series.data.data[series.data.plotColumns[entry.value]]!.values.toList();
  if (allData.isEmpty) {
    return NumericalChartAxis.fromFixedBounds(
      axisInfo: axisInfo,
      bounds: const Bounds(0, 1),
      theme: theme,
    );
  }
  dynamic data = series.data.data[series.data.plotColumns[entry.value]]!.values.toList().first;
  if (data is double) {
    return NumericalChartAxis.fromBounds(
      axisInfo: axisInfo,
      boundsList: allSeries.entries
          .map((e) => e.key.data.calculateBounds(
                e.key.data.plotColumns[e.value]!,
                drillDownDataPoints,
              ))
          .toList(),
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
    List<List<DateTime>> values;
    if (drillDownDataPoints.isEmpty) {
      values = allSeries.entries
          .map((e) =>
              e.key.data.data[e.key.data.plotColumns[e.value]]!.values.map((e) => e as DateTime).toList())
          .toList();
    } else {
      values = allSeries.entries
          .map((e) => e.key.data.data[e.key.data.plotColumns[e.value]]!.entries
              .where((entry) => drillDownDataPoints.contains(entry.key))
              .map((entry) => entry.value as DateTime)
              .toList())
          .toList();
    }

    return DateTimeChartAxis.fromData(
      axisInfo: axisInfo,
      data: values,
      theme: theme,
    );
  }

  throw AxisUpdateException("Data type not supported.");
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

/// Get the shared x-axis map from a list of series.
Map<Series, AxisId> getSharedXaxisMap(List<Series> seriesList) {
  Map<Series, AxisId> result = {};
  for (Series series in seriesList) {
    if (series.data.plotColumns.containsKey(AxisId(AxisLocation.bottom))) {
      if (series.data.plotColumns.containsKey(AxisId(AxisLocation.top))) {
        throw AxisUpdateException("Shared Series cannot have both top and bottom axes.");
      }
      result[series] = AxisId(AxisLocation.bottom);
    } else if (series.data.plotColumns.containsKey(AxisId(AxisLocation.top))) {
      result[series] = AxisId(AxisLocation.top);
    } else {
      throw AxisUpdateException("Series sharing the x-axis must have either a top or bottom axis.");
    }
  }
  return result;
}

/// Get the shared y-axis map from a list of series.
Map<Series, AxisId> getSharedYaxisMap(List<Series> seriesList) {
  Map<Series, AxisId> result = {};
  for (Series series in seriesList) {
    if (series.data.plotColumns.containsKey(AxisId(AxisLocation.left))) {
      if (series.data.plotColumns.containsKey(AxisId(AxisLocation.right))) {
        throw AxisUpdateException("Shared Series cannot have both left and right axes.");
      }
      result[series] = AxisId(AxisLocation.left);
    } else if (series.data.plotColumns.containsKey(AxisId(AxisLocation.right))) {
      result[series] = AxisId(AxisLocation.right);
    } else {
      throw AxisUpdateException("Series sharing the y-axis must have either a left or right axis.");
    }
  }
  return result;
}

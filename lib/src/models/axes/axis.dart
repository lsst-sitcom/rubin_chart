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
typedef TapAxisCallback = void Function(int axisIndex);

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

/// The orientation of a chart axis
enum AxisOrientation {
  horizontal,
  vertical,
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
  final bool isBounded;

  const ChartAxisInfo({
    required this.label,
    required this.axisId,
    this.isInverted = false,
    this.mapping = const LinearMapping(),
    this.isBounded = true,
  });
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

  final AxisDataType dataType;

  final ChartTheme theme;

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

  double toDouble(T value);
  T fromDouble(double value);

  void translate(double delta) {
    if (info.isInverted) {
      delta = -delta;
    }
    // Perform the translation
    double min = bounds.min + delta;
    double max = bounds.max + delta;

    if (delta < 0 && (dataBounds.min < min || dataBounds.max < max)) {
      updateTicksAndBounds(Bounds(min, max));
    } else if (delta > 0 && (dataBounds.min > min || dataBounds.max > max)) {
      updateTicksAndBounds(Bounds(min, max));
    }
  }

  /// Update the tick marks and adjust the bounds if necessary
  void updateTicksAndBounds(Bounds<double> bounds) {
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

  void scale(double scale) {
    _scale(scale);
    controller?.update(bounds: bounds, ticks: ticks);
  }

  void _scale(double scale);

  ChartAxisInfo get info => _info;

  Bounds<double> get bounds => _bounds;

  AxisTicks get ticks => _ticks;

  void update({
    ChartAxisInfo? info,
    Bounds<double>? bounds,
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

  static NumericalChartAxis fromData({
    required ChartAxisInfo axisInfo,
    required List<List<double>> data,
    required ChartTheme theme,
    bool showTicks = true,
    bool showLabels = true,
  }) {
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

  static NumericalChartAxis fromBounds({
    required ChartAxisInfo axisInfo,
    required List<Bounds<double>> boundsList,
    required ChartTheme theme,
    bool showTicks = true,
    bool showLabels = true,
  }) {
    double min = boundsList[0].min.toDouble();
    double max = boundsList[0].max.toDouble();
    for (Bounds<double> bounds in boundsList) {
      min = math.min(min, bounds.min.toDouble());
      max = math.max(max, bounds.max.toDouble());
    }
    Bounds<double> dataBounds = Bounds(min, max);
    AxisTicks ticks = AxisTicks.fromBounds(dataBounds, theme.minTicks, theme.maxTicks, true);
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

  NumericalChartAxis addData(
    List<Bounds<double>> bounds,
    ChartTheme theme,
  ) =>
      fromBounds(
        axisInfo: info,
        boundsList: [this.bounds, ...bounds],
        theme: theme,
      );

  @override
  double toDouble(double value) => value;

  @override
  double fromDouble(double value) => value;

  @override
  AxisTicks _updateTicks(Bounds<double> bounds) {
    return AxisTicks.fromBounds(bounds, theme.minTicks, theme.maxTicks, false);
  }

  @override
  void _scale(double scale) {
    double min = bounds.min;
    double max = bounds.max;
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
    required super.dataBounds,
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
    AxisTicks ticks = AxisTicks.fromBounds(dataBounds, theme.minTicks, theme.maxTicks, true);
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
    throw UnimplementedError();
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
    return AxisTicks.fromBounds(bounds, theme.minTicks, theme.maxTicks, false);
  }

  @override
  void _scale(double scale) {
    double min = bounds.min;
    double max = bounds.max;
    double midpoint = (min + max) / 2;
    double range = max - min;
    double delta = range / scale / 2;

    min = midpoint - delta;
    max = midpoint + delta;

    _ticks = AxisTicks.fromBounds(Bounds(min, max), theme.minTicks, theme.maxTicks, false);
    _bounds = Bounds(min, max);
  }
}

class MissingAxisException implements Exception {
  final String message;

  MissingAxisException(this.message);

  @override
  String toString() => message;
}

/// A [Rect] replacement that uses the main and cross axis instead of left, top, right, and bottom.
class AxisAlignedRect {
  /// The minimum value of the main axis.
  final double mainStart;

  /// The minimum value of the cross axis.
  final double crossStart;

  /// The maximum value of the main axis.
  final double mainEnd;

  /// The maximum value of the cross axis.
  final double crossEnd;

  final AxisOrientation mainAxisAlignment;

  AxisAlignedRect({
    required this.mainStart,
    required this.crossStart,
    required this.mainEnd,
    required this.crossEnd,
    required this.mainAxisAlignment,
  }) : assert(
            mainAxisAlignment == AxisOrientation.vertical || mainAxisAlignment == AxisOrientation.horizontal);

  // Helper to create from main and cross coordinates directly
  static AxisAlignedRect fromMainCross(
      double mainStart, double crossStart, double mainEnd, double crossEnd, AxisOrientation orientation) {
    return AxisAlignedRect(
      mainStart: mainStart,
      crossStart: crossStart,
      mainEnd: mainEnd,
      crossEnd: crossEnd,
      mainAxisAlignment: orientation,
    );
  }

  static AxisAlignedRect fromRect(Rect rect, AxisOrientation orientation) {
    if (orientation == AxisOrientation.vertical) {
      return AxisAlignedRect(
        mainStart: rect.top,
        crossStart: rect.left,
        mainEnd: rect.bottom,
        crossEnd: rect.right,
        mainAxisAlignment: orientation,
      );
    } else {
      return AxisAlignedRect(
        mainStart: rect.left,
        crossStart: rect.top,
        mainEnd: rect.right,
        crossEnd: rect.bottom,
        mainAxisAlignment: orientation,
      );
    }
  }

  // Convert to Flutter's Rect depending on orientation
  Rect toRect() {
    double left;
    double right;
    double top;
    double bottom;

    if (mainAxisAlignment == AxisOrientation.vertical) {
      if (crossStart < crossEnd) {
        left = crossStart;
        right = crossEnd;
      } else {
        left = crossEnd;
        right = crossStart;
      }
      if (mainStart < mainEnd) {
        top = mainStart;
        bottom = mainEnd;
      } else {
        top = mainEnd;
        bottom = mainStart;
      }
    } else {
      if (crossStart < crossEnd) {
        top = crossStart;
        bottom = crossEnd;
      } else {
        top = crossEnd;
        bottom = crossStart;
      }
      if (mainStart < mainEnd) {
        left = mainStart;
        right = mainEnd;
      } else {
        left = mainEnd;
        right = mainStart;
      }
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  Offset getOffset(double main, double cross) {
    return mainAxisAlignment == AxisOrientation.vertical ? Offset(cross, main) : Offset(main, cross);
  }

  bool inMain(double main) =>
      (mainStart <= main && main <= mainEnd) || (mainEnd <= main && main <= mainStart);

  bool inCross(double cross) =>
      (crossStart <= cross && cross <= crossEnd) || (crossEnd <= cross && cross <= crossStart);
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
    return NumericalChartAxis.fromBounds(
      axisInfo: axisInfo,
      boundsList:
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
    return DateTimeChartAxis.fromData(
      axisInfo: axisInfo,
      data: allSeries.entries
          .map((e) =>
              e.key.data.data[e.key.data.plotColumns[e.value]]!.values.map((e) => e as DateTime).toList())
          .toList(),
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

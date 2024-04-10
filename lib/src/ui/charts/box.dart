import 'package:flutter/material.dart';
import 'package:rubin_chart/src/models/axes/axes.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/ticks.dart';
import 'package:rubin_chart/src/models/binned.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/ui/chart.dart';
import 'package:rubin_chart/src/ui/charts/cartesian.dart';
import 'package:rubin_chart/src/utils/utils.dart';

/// A single box in a [BoxChart], with whiskers for min/max and the mean and median.
class BoxChartBox extends BinnedData {
  AxisOrientation mainAxisAlignment;

  BoxChartBox({
    required super.data,
    required super.mainStart,
    required super.mainEnd,
    super.fillColor,
    super.edgeColor,
    super.edgeWidth = 1,
    required this.mainAxisAlignment,
  });

  /// The data in the box sorted by value.
  final List<MapEntry<Object, double>> _sortedCrossAxisData = [];

  /// Empty the sorted data list.
  void empty() => _sortedCrossAxisData.clear();

  // Efficiently find the insertion index using binary search
  int _findInsertionIndex(double value) {
    int min = 0;
    int max = _sortedCrossAxisData.length;
    while (min < max) {
      int mid = min + ((max - min) >> 1);
      if (_sortedCrossAxisData[mid].value < value) {
        min = mid + 1;
      } else {
        max = mid;
      }
    }
    return min;
  }

  /// Get the cross-axis entry from the data.
  double getCrossEntry(List<double> data) {
    if (mainAxisAlignment == AxisOrientation.horizontal) {
      return data[1];
    } else {
      return data[0];
    }
  }

  /// Get the minimum value from the sorted data list.
  double get min => _sortedCrossAxisData.first.value;

  /// Get the maximum value from the sorted data list.
  double get max => _sortedCrossAxisData.last.value;

  /// Get the mean value from the sorted data list.
  double get mean {
    final sum = _sortedCrossAxisData.fold<double>(0, (prev, element) => prev + element.value);
    return sum / _sortedCrossAxisData.length;
  }

  /// Get the median value from the sorted data list.
  double get median => _percentile(50);

  /// Get the first quartile value from the sorted data list.
  double get quartile1 => _percentile(25);

  /// Get the third quartile value from the sorted data list.
  double get quartile3 => _percentile(75);

  /// Get the number of data points in the box.
  @override
  int get count => _sortedCrossAxisData.length;

  double _percentile(int percentile) {
    if (_sortedCrossAxisData.isEmpty) return 0.0;
    double position = (percentile / 100) * (_sortedCrossAxisData.length - 1) + 1;
    int index = position.toInt() - 1;
    double fraction = position - (index + 1);
    if (index + 1 >= _sortedCrossAxisData.length) return _sortedCrossAxisData.last.value;
    return _sortedCrossAxisData[index].value +
        fraction * (_sortedCrossAxisData[index + 1].value - _sortedCrossAxisData[index].value);
  }

  /// Get the data IDs in the box.
  Set<Object> get dataIds => _sortedCrossAxisData.map((e) => e.key).toSet();

  /// Get the sorted data list.
  List<MapEntry<Object, double>> get sortedCrossAxisData => [..._sortedCrossAxisData];

  List<MapEntry<Object, double>> inRange(double start, double end) {
    return _sortedCrossAxisData.where((element) => start <= element.value && element.value < end).toList();
  }

  /// Insert a key-value pair to the sorted data list.
  @override
  void insert(Object key, List<double> value) {
    MapEntry<Object, double> entry = MapEntry(key, getCrossEntry(value));
    int index = _findInsertionIndex(entry.value);
    _sortedCrossAxisData.insert(index, entry);
  }

  @override
  bool contains(List<double> data) {
    if (mainAxisAlignment == AxisOrientation.horizontal) {
      return mainStart <= data[0] && data[0] < mainEnd;
    } else {
      return mainStart <= data[1] && data[1] < mainEnd;
    }
  }

  /// Convert the bounds of a bin to a [Rect] in pixel coordinates.
  @override
  Rect rectToPixel({
    required ChartAxes axes,
    required Size chartSize,
    required AxisOrientation mainAxisAlignment,
    Offset offset = Offset.zero,
  }) {
    double x0;
    double xf;
    double y0;
    double yf;
    if (mainAxisAlignment == AxisOrientation.horizontal) {
      x0 = mainStart;
      xf = mainEnd;
      y0 = quartile1;
      yf = quartile3;
    } else {
      x0 = quartile1;
      xf = quartile3;
      y0 = mainStart;
      yf = mainEnd;
    }
    Offset topLeft = axes.doubleToPixel([x0, y0], chartSize) + offset;
    Offset bottomRight = axes.doubleToPixel([xf, yf], chartSize) + offset;
    return Rect.fromPoints(topLeft, bottomRight);
  }
}

/// Information for a histogram chart
@immutable
class BoxChartInfo extends BinnedChartInfo {
  final AxisOrientation mainAxisAlignment;

  BoxChartInfo({
    required super.id,
    required super.allSeries,
    super.title,
    super.theme,
    super.legend,
    super.axisInfo,
    super.colorCycle,
    super.interiorAxisLabelLocation,
    super.flexX,
    super.flexY,
    super.xToYRatio,
    super.nBins,
    super.doFill = true,
    super.edges,
    super.onSelection,
    super.onDrillDown,
    this.mainAxisAlignment = AxisOrientation.horizontal,
  })  : assert(nBins != null || edges != null),
        super(builder: BoxChart.builder);

  Map<Object, ChartAxes> initializeAxes({required Set<Object> drillDownDataPoints}) => initializeSimpleAxes(
        seriesList: allSeries,
        axisInfo: axisInfo,
        theme: theme,
        axesInitializer: CartesianChartAxes.fromAxes,
        drillDownDataPoints: drillDownDataPoints,
      );
}

class BoxChart extends BinnedChart {
  const BoxChart({
    super.key,
    required BoxChartInfo info,
    super.selectionController,
    super.drillDownController,
    super.axisControllers = const {},
    super.hiddenAxes = const [],
  }) : super(info: info);

  @override
  BoxChartState createState() => BoxChartState();

  static Widget builder({
    required ChartInfo info,
    Map<AxisId, AxisController>? axisControllers,
    SelectionController? selectionController,
    SelectionController? drillDownController,
    List<AxisId>? hiddenAxes,
  }) {
    return BoxChart(
      info: info as BoxChartInfo,
      selectionController: selectionController,
      axisControllers: axisControllers ?? {},
      hiddenAxes: hiddenAxes ?? [],
    );
  }
}

class BoxChartState extends BinnedChartState<BoxChart> {
  @override
  BoxChartInfo get info => widget.info as BoxChartInfo;

  @override
  AxisOrientation get mainAxisAlignment => info.mainAxisAlignment;

  @override
  void didUpdateWidget(BoxChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initBins();
  }

  @override
  void initAxesAndBins() {
    _initAxes();
    _initBins();
  }

  @override
  void updateAxesAndBins() => _initBins();

  void _initAxes() {
    // Populate the axis controllers
    axisControllers.addAll(widget.axisControllers.values);

    // Initialize the axes
    allAxes.addAll(info.initializeAxes(drillDownDataPoints: drillDownDataPoints));

    // Initialize the axis controllers
    for (ChartAxes chartAxes in allAxes.values) {
      for (ChartAxis axis in chartAxes.axes.values) {
        if (widget.axisControllers.containsKey(axis.info.axisId)) {
          axis.controller = widget.axisControllers[axis.info.axisId];
        }
        if (widget.hiddenAxes.contains(axis.info.axisId)) {
          axis.showLabels = false;
        }
      }
    }

    // Subscribe to the axis controllers
    for (ChartAxes axes in allAxes.values) {
      for (ChartAxis axis in axes.axes.values) {
        if (widget.axisControllers.containsKey(axis.info.axisId)) {
          widget.axisControllers[axis.info.axisId]!
              .subscribe(({Bounds<double>? bounds, AxisTicks? ticks, ChartAxisInfo? info}) {
            axis.update(bounds: bounds, ticks: ticks, info: info, state: this);
            setState(() {});
          });
        }
      }
    }
  }

  void _initBins() {
    // Clear the parameters
    binContainers.clear();

    ChartAxis mainAxis;
    int mainCoordIdx;
    if (mainAxisAlignment == AxisOrientation.horizontal) {
      mainAxis = allAxes.values.first.axes.values.first;
      mainCoordIdx = 0;
    } else {
      mainAxis = allAxes.values.first.axes.values.last;
      mainCoordIdx = 1;
    }
    ChartAxes axes = allAxes.values.first;

    // Calculate the edges for the bins
    List<double> edges = [];
    if (widget.info.edges != null) {
      edges.addAll(widget.info.edges!);
    } else {
      double binWidth = 1 / widget.info.nBins!;
      for (int i = 0; i < widget.info.nBins!; i++) {
        List<double> coords =
            axes.doubleFromPixel(Offset(i * binWidth, (i + 1) * binWidth), const Size(1, 1));
        edges.add(coords[mainCoordIdx]);
      }

      if (mainAxis.info.isInverted) {
        edges = edges.reversed.toList();
      }
    }

    // Create the bins
    for (int i = 0; i < widget.info.allSeries.length; i++) {
      Series series = widget.info.allSeries[i];
      binContainers[series.id] = BinnedDataContainer(
        bins: List.generate(edges.length - 1, (j) {
          return BoxChartBox(
            mainAxisAlignment: mainAxisAlignment,
            mainStart: edges[j],
            mainEnd: edges[j + 1],
            data: {},
            fillColor:
                series.marker?.color ?? widget.info.theme.colorCycle[i % widget.info.theme.colorCycle.length],
            edgeColor: series.marker?.edgeColor,
            edgeWidth: (series.marker?.size ?? 10) / 10,
          );
        }),
      );
      Map<Object, List<dynamic>> data = {};
      List<Object> dataIds = series.data.data.values.first.keys.toList();
      for (int i = 0; i < series.data.length; i++) {
        data[dataIds[i]] = series.data.getRow(i);
      }
      for (MapEntry<Object, dynamic> entry in data.entries) {
        List<double> coords = axes.dataToDouble(entry.value);
        binContainers[series.id]!.insert(entry.key, coords);
      }
    }
  }
}

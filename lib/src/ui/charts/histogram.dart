import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rubin_chart/src/models/axes/axes.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/ticks.dart';
import 'package:rubin_chart/src/models/binned.dart';
import 'package:rubin_chart/src/models/marker.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/ui/axis_painter.dart';
import 'package:rubin_chart/src/ui/chart.dart';
import 'package:rubin_chart/src/ui/charts/cartesian.dart';
import 'package:rubin_chart/src/utils/utils.dart';

/// A single bin in a histogram.
class HistogramBin extends BinnedData {
  AxisOrientation mainAxisAlignment;

  HistogramBin({
    required super.data,
    required super.mainStart,
    required super.mainEnd,
    super.fillColor,
    super.edgeColor,
    super.edgeWidth = 1,
    required this.mainAxisAlignment,
  });

  @override
  String toString() {
    return "HistogramBin(start: $mainStart, end: $mainEnd, count: $count)";
  }

  @override
  void insert(Object dataId, List<double> data) {
    this.data[dataId] = data;
  }

  @override
  bool contains(List<double> data) {
    return data[0] >= mainStart && data[0] < mainEnd;
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
      y0 = 0;
      yf = count.toDouble();
    } else {
      x0 = 0;
      xf = count.toDouble();
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
class HistogramInfo extends BinnedChartInfo {
  HistogramInfo({
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
  })  : assert(nBins != null || edges != null),
        super(builder: Histogram.builder);
}

class Histogram extends BinnedChart {
  const Histogram({
    super.key,
    required HistogramInfo info,
    super.selectionController,
    super.axisControllers = const {},
    super.hiddenAxes = const [],
  }) : super(info: info);

  @override
  HistogramState createState() => HistogramState();

  static Widget builder({
    required ChartInfo info,
    Map<AxisId, AxisController>? axisControllers,
    SelectionController? selectionController,
    List<AxisId>? hiddenAxes,
  }) {
    return Histogram(
      info: info as HistogramInfo,
      selectionController: selectionController,
      axisControllers: axisControllers ?? {},
      hiddenAxes: hiddenAxes ?? [],
    );
  }
}

class HistogramState extends BinnedChartState<Histogram> {
  @override
  HistogramInfo get info => widget.info as HistogramInfo;

  late AxisOrientation mainAxisAlignment;

  @override
  void updateAxesAndBins() => initAxesAndBins();

  @override
  void initAxesAndBins() {
    // Clear the parameters
    axisControllers.clear();
    binContainers.clear();
    allAxes.clear();

    // Add the axis controllers
    axisControllers.addAll(widget.axisControllers.values);

    // Get the actual bounds for the bins and main axis
    List<Series> allSeries = widget.info.allSeries;
    if (allSeries.isEmpty) {
      throw UnimplementedError('Histograms must have at least one series for now');
    }
    double min = allSeries.first.data.calculateBounds(allSeries.first.data.plotColumns.values.first).min;
    double max = allSeries.first.data.calculateBounds(allSeries.first.data.plotColumns.values.first).max;
    List<List<String>> uniqueValues = [];
    for (Series series in allSeries) {
      if (series.data.plotColumns.length != 1) {
        throw ChartInitializationException('Histograms must have exactly one data column');
      }
      Bounds<double> bounds = series.data.calculateBounds(series.data.plotColumns.values.first);
      min = math.min(min, bounds.min);
      max = math.max(max, bounds.max);
      if (series.data.columnTypes[series.data.plotColumns.values.first] == ColumnDataType.string) {
        uniqueValues
            .add(series.data.data[series.data.plotColumns.values.first]!.values.cast<String>().toList());
      }
    }

    // Initialize the main axis based on the [SeriesData].
    ChartAxis mainAxis;
    AxisId mainAxisId = allSeries.first.data.plotColumns.keys.first;
    ChartAxisInfo mainAxisInfo = widget.info.axisInfo[mainAxisId]!;
    if (allSeries.first.data.columnTypes[allSeries.first.data.plotColumns.values.first] ==
        ColumnDataType.datetime) {
      mainAxis = DateTimeChartAxis.fromBounds(
        boundsList: [Bounds(min, max)],
        axisInfo: mainAxisInfo,
        theme: widget.info.theme,
      );
    } else if (allSeries.first.data.columnTypes[allSeries.first.data.plotColumns.values.first] ==
        ColumnDataType.number) {
      mainAxis = NumericalChartAxis.fromBounds(
        boundsList: [Bounds(min, max)],
        axisInfo: mainAxisInfo,
        theme: widget.info.theme,
      );
    } else if (allSeries.first.data.columnTypes[allSeries.first.data.plotColumns.values.first] ==
        ColumnDataType.string) {
      mainAxis = StringChartAxis.fromData(
        data: uniqueValues,
        axisInfo: mainAxisInfo,
        theme: widget.info.theme,
      );
    } else {
      throw ChartInitializationException(
          'Unable to determine column type for ${allSeries.first.data.plotColumns.values.first}');
    }
    baseLocation = mainAxis.info.axisId.location;
    if (baseLocation == AxisLocation.left || baseLocation == AxisLocation.right) {
      mainAxisAlignment = AxisOrientation.vertical;
    } else if (baseLocation == AxisLocation.top || baseLocation == AxisLocation.bottom) {
      mainAxisAlignment = AxisOrientation.horizontal;
    } else if (baseLocation == AxisLocation.angular || baseLocation == AxisLocation.radial) {
      throw UnimplementedError('Polar histograms are not yet supported');
    } else {
      throw ChartInitializationException('Invalid histogram axis location');
    }

    // Calculate the edges for the bins
    List<double> edges = [];
    if (widget.info.edges != null) {
      edges.addAll(widget.info.edges!);
    } else {
      if (widget.info.nBins == null) {
        throw Exception('Either nBins or edges must be provided');
      }
      // Create bins using the correct mapping to give the bins equal width in the image.
      // If a non-linear scaling is used, such as log scaling, that will be accounted
      // for in the bin edges.

      // We need x and y axes to create [ChartAxes], so we create a dummy Y axis.
      AxisId dummyAxisId = AxisId(AxisLocation.left, mainAxis.info.axisId.axesId);
      int coordIdx = 0;
      if (mainAxisAlignment == AxisOrientation.vertical) {
        dummyAxisId = AxisId(AxisLocation.bottom, mainAxis.info.axisId.axesId);
        coordIdx = 1;
      }
      ChartAxis dummyAxis = NumericalChartAxis.fromBounds(
        boundsList: [const Bounds(0, 1)],
        axisInfo: ChartAxisInfo(label: "dummy", axisId: dummyAxisId),
        theme: widget.info.theme,
      );
      ChartAxes axes =
          CartesianChartAxes.fromAxes(axes: {mainAxis.info.axisId: mainAxis, dummyAxisId: dummyAxis});
      double binWidth = 1 / widget.info.nBins!;
      for (int i = 0; i < widget.info.nBins!; i++) {
        List<double> coords =
            axes.doubleFromPixel(Offset(i * binWidth, (i + 1) * binWidth), const Size(1, 1));
        edges.add(coords[coordIdx]);
      }

      if (mainAxisInfo.isInverted) {
        edges = edges.reversed.toList();
      }
    }

    // Create the bins
    for (int i = 0; i < widget.info.allSeries.length; i++) {
      Series series = widget.info.allSeries[i];
      binContainers[series.id] = BinnedDataContainer(
        bins: List.generate(edges.length - 1, (j) {
          return HistogramBin(
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
      Map<Object, dynamic> data = series.data.data[series.data.plotColumns.values.first]!;
      for (MapEntry<Object, dynamic> entry in data.entries) {
        binContainers[series.id]!.insert(entry.key, [mainAxis.toDouble(entry.value)]);
      }
    }

    // Create the cross-axis
    final maxCount = binContainers.values
        .expand((histogramBins) => histogramBins.bins)
        .map((bin) => (bin as HistogramBin).count)
        .reduce((a, b) => a > b ? a : b);
    ChartAxisInfo? crossAxisInfo;
    for (AxisId id in widget.info.axisInfo.keys) {
      if (mainAxisAlignment == AxisOrientation.horizontal) {
        if (id.location == AxisLocation.left || id.location == AxisLocation.right) {
          crossAxisInfo = widget.info.axisInfo[id];
          break;
        }
      } else if (mainAxisAlignment == AxisOrientation.vertical) {
        if (id.location == AxisLocation.top || id.location == AxisLocation.bottom) {
          crossAxisInfo = widget.info.axisInfo[id];
          break;
        }
      }
    }
    if (crossAxisInfo == null) {
      AxisId crossAxisId;
      if (mainAxisAlignment == AxisOrientation.vertical) {
        crossAxisId = AxisId(AxisLocation.bottom, mainAxis.info.axisId.axesId);
      } else if (mainAxisAlignment == AxisOrientation.horizontal) {
        crossAxisId = AxisId(AxisLocation.left, mainAxis.info.axisId.axesId);
      } else {
        throw UnimplementedError('Polar histograms are not yet supported');
      }
      crossAxisInfo = ChartAxisInfo(
        label: "count",
        axisId: crossAxisId,
        isInverted: mainAxisAlignment == AxisOrientation.horizontal,
      );
    }
    NumericalChartAxis crossAxis = NumericalChartAxis.fromBounds(
      boundsList: [Bounds(0, maxCount.toDouble())],
      axisInfo: crossAxisInfo,
      theme: widget.info.theme,
    );

    // Create the [ChartAxes].
    if (mainAxisAlignment == AxisOrientation.horizontal) {
      allAxes[crossAxis.info.axisId.axesId] =
          CartesianChartAxes(axes: {mainAxis.info.axisId: mainAxis, crossAxis.info.axisId: crossAxis});
    } else {
      allAxes[crossAxis.info.axisId.axesId] =
          CartesianChartAxes(axes: {crossAxis.info.axisId: crossAxis, mainAxis.info.axisId: mainAxis});
    }

    // Subscribe to the axis controllers
    if (widget.axisControllers.containsKey(mainAxis.info.axisId)) {
      mainAxis.controller = widget.axisControllers[mainAxis.info.axisId];
    }
    if (widget.hiddenAxes.contains(mainAxis.info.axisId)) {
      mainAxis.showLabels = false;
    }
    if (widget.axisControllers.containsKey(crossAxis.info.axisId)) {
      crossAxis.controller = widget.axisControllers[crossAxis.info.axisId];
    }
    if (widget.hiddenAxes.contains(crossAxis.info.axisId)) {
      crossAxis.showLabels = false;
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
}

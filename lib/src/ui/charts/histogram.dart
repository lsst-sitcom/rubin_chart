import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rubin_chart/src/models/axes/axes.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/ticks.dart';
import 'package:rubin_chart/src/models/marker.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/ui/axis_painter.dart';
import 'package:rubin_chart/src/ui/chart.dart';
import 'package:rubin_chart/src/ui/charts/cartesian.dart';
import 'package:rubin_chart/src/utils/utils.dart';

/// A single bin in a histogram.
class HistogramBin {
  final double start;
  final double end;
  final Color? fillColor;
  final Color? edgeColor;
  final double edgeWidth;
  final List<Object> dataIds;

  HistogramBin({
    required this.start,
    required this.end,
    required this.dataIds,
    this.fillColor,
    this.edgeColor,
    this.edgeWidth = 1,
  });

  int get count => dataIds.length;

  @override
  String toString() {
    return "HistogramBin(start: $start, end: $end, count: $count)";
  }

  /// Convert the bounds of a bin to a [Rect] in pixel coordinates.
  Rect toRect({
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
      x0 = start;
      xf = end;
      y0 = 0;
      yf = count.toDouble();
    } else {
      x0 = 0;
      xf = count.toDouble();
      y0 = start;
      yf = end;
    }
    Offset topLeft = axes.doubleToPixel([x0, y0], chartSize) + offset;
    Offset bottomRight = axes.doubleToPixel([xf, yf], chartSize) + offset;
    return Rect.fromPoints(topLeft, bottomRight);
  }
}

/// A collection of bins in a histogram.
class HistogramBins {
  /// The bins in the histogram.
  final List<HistogramBin> bins;

  /// The number of data points that did not fit into any bin.
  int missingData = 0;

  HistogramBins(this.bins);

  /// Insert a data point into the histogram.
  bool insert(Object dataId, double data) {
    for (HistogramBin bin in bins) {
      if (bin.start <= data && data < bin.end) {
        bin.dataIds.add(dataId);
        return true;
      }
    }
    // The data point did not fit into any bin.
    missingData++;
    return false;
  }

  /// Insert a list of data points into the histogram.
  /// The number of data points that did not fit into any bin is returned.
  int insertAll(Map<Object, double> data) {
    for (MapEntry<Object, double> entry in data.entries) {
      insert(entry.key, entry.value);
    }
    return missingData;
  }
}

/// Information for a histogram chart
@immutable
class HistogramInfo extends ChartInfo {
  /// The number of bins to use
  /// Either [nBins] or [edges] must be provided.
  final int? nBins;

  /// Whether to fill the bins or leave them as outlines.
  final bool doFill;

  /// The bins to use for the histogram.
  /// Either nBins or bins must be provided.
  final List<double>? edges;

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
    this.nBins,
    this.doFill = true,
    this.edges,
  })  : assert(nBins != null || edges != null),
        super(builder: Histogram.builder);
}

/// Represents a selected bin in a histogram chart.
class SelectedBin {
  final BigInt seriesIndex;
  final int binIndex;

  SelectedBin(this.seriesIndex, this.binIndex);
}

/// Represents a selected range of bins in a histogram chart.
class SelectedBinRange {
  final BigInt seriesIndex;
  int startBinIndex;
  int? endBinIndex;

  SelectedBinRange(this.seriesIndex, this.startBinIndex, this.endBinIndex);

  /// Returns a list of [HistogramBin] objects within the selected range of bins.
  List<HistogramBin> getBins(Map<BigInt, HistogramBins> allBins) {
    if (endBinIndex == null) {
      return [allBins[seriesIndex]!.bins[startBinIndex]];
    }
    return allBins[seriesIndex]!.bins.sublist(startBinIndex, endBinIndex);
  }

  /// Returns a list of selected data IDs within the selected range of bins.
  Set<Object> getSelectedDataIds(Map<BigInt, HistogramBins> allBins) {
    Set<Object> dataIds = {};
    for (HistogramBin bin in getBins(allBins)) {
      dataIds.addAll(bin.dataIds);
    }
    return dataIds;
  }

  /// Returns true if the given bin index is within the selected range of bins.
  bool containsBin(int binIndex) {
    if (endBinIndex == null) {
      return startBinIndex == binIndex;
    }
    return startBinIndex <= binIndex && binIndex <= endBinIndex!;
  }
}

class Histogram extends StatefulWidget {
  final HistogramInfo info;
  final SelectionController? selectionController;
  final Map<AxisId, AxisController> axisControllers;
  final List<AxisId> hiddenAxes;

  const Histogram({
    super.key,
    required this.info,
    this.selectionController,
    this.axisControllers = const {},
    this.hiddenAxes = const [],
  });

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

class HistogramState<T extends Object> extends State<Histogram> with ChartMixin, Scrollable2DChartMixin {
  @override
  SeriesList get seriesList => SeriesList(
        widget.info.allSeries,
        widget.info.colorCycle ?? widget.info.theme.colorCycle,
      );

  /// The axes of the chart.
  @override
  Map<Object, ChartAxes> get axes => _axes;

  /// The axes of the chart.
  final Map<Object, ChartAxes> _axes = {};

  final Map<BigInt, HistogramBins> _allBins = {};

  SelectedBinRange? selectedBins;

  /// The location of the base of the histogram bins.
  /// This is used to determine the orientation and layout of the histogram.
  late AxisLocation baseLocation;

  late AxisOrientation mainAxisAlignment;

  @override
  void didUpdateWidget(Histogram oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initAxesAndBins();
  }

  @override
  void initState() {
    super.initState();
    // Add key detector
    focusNode.addListener(focusNodeListener);
    // Initialize the axes and bins
    _initAxesAndBins();
  }

  void _initAxesAndBins() {
    // Clear the parameters
    axisControllers.clear();
    _allBins.clear();
    _axes.clear();

    // Add the axis controllers
    axisControllers.addAll(widget.axisControllers.values);

    // Subscribe to the selection controller
    if (widget.selectionController != null) {
      widget.selectionController!.subscribe((Set<Object> dataPoints) {
        selectedDataPoints = dataPoints;
        setState(() {});
      });
    }

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
      _allBins[series.id] = HistogramBins(
        List.generate(edges.length - 1, (j) {
          return HistogramBin(
            start: edges[j],
            end: edges[j + 1],
            dataIds: [],
            fillColor:
                series.marker?.color ?? widget.info.theme.colorCycle[i % widget.info.theme.colorCycle.length],
            edgeColor: series.marker?.edgeColor,
            edgeWidth: (series.marker?.size ?? 10) / 10,
          );
        }),
      );
      Map<Object, dynamic> data = series.data.data[series.data.plotColumns.values.first]!;
      for (MapEntry<Object, dynamic> entry in data.entries) {
        _allBins[series.id]!.insert(entry.key, mainAxis.toDouble(entry.value));
      }
    }

    // Create the cross-axis
    final maxCount = _allBins.values
        .expand((histogramBins) => histogramBins.bins)
        .map((bin) => bin.count)
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
      _axes[crossAxis.info.axisId.axesId] =
          CartesianChartAxes(axes: {mainAxis.info.axisId: mainAxis, crossAxis.info.axisId: crossAxis});
    } else {
      _axes[crossAxis.info.axisId.axesId] =
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
    for (ChartAxes axes in _axes.values) {
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

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];

    AxisPainter axisPainter = CartesianAxisPainter(
      allAxes: _axes,
      theme: widget.info.theme,
    );

    // Add a BarPainter widget for each [Series].
    int colorIndex = 0;
    for (int i = 0; i < seriesList.length; i++) {
      if (colorIndex >= widget.info.theme.colorCycle.length) {
        colorIndex = 0;
      }
      Series series = seriesList[i];
      children.add(
        Positioned.fill(
          child: CustomPaint(
            painter: HistogramPainter(
              mainAxisAlignment: mainAxisAlignment,
              axes: _axes[series.axesId]!,
              errorBars: series.errorBars,
              allBins: _allBins,
              selectedBins: selectedBins,
              tickLabelMargin: EdgeInsets.only(
                left: axisPainter.margin.left + axisPainter.tickPadding,
                right: axisPainter.margin.right + axisPainter.tickPadding,
                top: axisPainter.margin.top + axisPainter.tickPadding,
                bottom: axisPainter.margin.bottom + axisPainter.tickPadding,
              ),
            ),
          ),
        ),
      );
    }

    // Draw the axes
    children.add(
      Positioned.fill(
        child: CustomPaint(
          painter: axisPainter,
        ),
      ),
    );

    return Focus(
        focusNode: focusNode,
        child: Listener(
            onPointerSignal: (PointerSignalEvent event) {
              if (event is PointerScrollEvent) {
                onPan(event, axisPainter);
              } else if (event is PointerScaleEvent) {
                onScale(event, axisPainter);
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (TapUpDetails details) {
                _onTapUp(details, axisPainter);
              },
              /*onPanStart: (DragStartDetails details) {
            _onDragStart(details, axisPainter);
          },
          onPanUpdate: (DragUpdateDetails details) {
            _onDragUpdate(details, axisPainter);
          },
          onPanEnd: (DragEndDetails details) {
            _onDragEnd(details, axisPainter);
          },
          onPanCancel: () {
            _onDragCancel();
          },*/
              child: Container(
                /*decoration: BoxDecoration(
              border: Border.all(
                color: Colors.red,
                width: 2,
              ),
              //borderRadius: BorderRadius.circular(10),
            ),*/
                child: Stack(children: children),
              ),
            )));
  }

  /// Handles the tap up event on the histogram chart.
  ///
  /// This method is called when the user taps on the histogram chart.
  /// It updates the selected bin based on the tap location,
  /// retrieves the data points associated with the selected bin,
  /// and updates the selection controller if available.
  void _onTapUp(TapUpDetails details, AxisPainter axisPainter) {
    focusNode.requestFocus();
    // Get the selected bin based on the tap location
    SelectedBin? selectedBin = _getBinOnTap(details.localPosition, axisPainter);
    selectedDataPoints = {};
    if (selectedBin != null) {
      if (selectedBins == null || selectedBins!.seriesIndex != selectedBin.seriesIndex || !isShifting) {
        selectedBins = SelectedBinRange(selectedBin.seriesIndex, selectedBin.binIndex, null);
      } else {
        if (selectedBins!.startBinIndex == selectedBin.binIndex) {
          selectedBins = null;
        } else if (selectedBins!.startBinIndex < selectedBin.binIndex) {
          selectedBins!.endBinIndex = selectedBin.binIndex;
        } else {
          selectedBins!.endBinIndex = selectedBins!.startBinIndex;
          selectedBins!.startBinIndex = selectedBin.binIndex;
        }
      }
      if (selectedBins != null) {
        selectedDataPoints = selectedBins!.getSelectedDataIds(_allBins);
      }
    } else {
      selectedBins = null;
    }

    // Update the selection controller if available
    if (widget.selectionController != null) {
      widget.selectionController!.updateSelection(widget.info.id, selectedDataPoints);
    }

    setState(() {});
  }

  /// Returns the selected bin based on the tap location.
  SelectedBin? _getBinOnTap(Offset location, AxisPainter axisPainter) {
    EdgeInsets tickLabelMargin = EdgeInsets.only(
      left: axisPainter.margin.left + axisPainter.tickPadding,
      right: axisPainter.margin.right + axisPainter.tickPadding,
      top: axisPainter.margin.top + axisPainter.tickPadding,
      bottom: axisPainter.margin.bottom + axisPainter.tickPadding,
    );
    Offset offset = Offset(tickLabelMargin.left, tickLabelMargin.top);
    ChartAxes axes = _axes.values.first;

    for (MapEntry<BigInt, HistogramBins> entry in _allBins.entries) {
      BigInt seriesIndex = entry.key;
      HistogramBins bins = entry.value;
      for (int i = 0; i < bins.bins.length; i++) {
        HistogramBin bin = bins.bins[i];
        Rect binRect = bin.toRect(
          axes: axes,
          chartSize: axisPainter.chartSize,
          mainAxisAlignment: mainAxisAlignment,
        );

        if (binRect.contains(location - offset)) {
          return SelectedBin(seriesIndex, i);
        }
      }
    }
    return null;
  }
}

/// A painter for a collection of histograms.
class HistogramPainter extends CustomPainter {
  /// The axes of the plot, used to project the markers onto the plot.
  final ChartAxes axes;

  /// The bins to draw
  final Map<BigInt, HistogramBins> allBins;

  /// The error bar style used for the series.
  final ErrorBars? errorBars;

  /// Offset from the lower left to make room for labels.
  final EdgeInsets tickLabelMargin;

  /// (Optional) selected bin
  final SelectedBinRange? selectedBins;

  /// Orientation of the main axis
  final AxisOrientation mainAxisAlignment;

  HistogramPainter({
    required this.axes,
    required this.mainAxisAlignment,
    required this.errorBars,
    required this.allBins,
    required this.selectedBins,
    this.tickLabelMargin = EdgeInsets.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the projection used for all points in the series
    Size plotSize = Size(size.width - tickLabelMargin.left - tickLabelMargin.right,
        size.height - tickLabelMargin.top - tickLabelMargin.bottom);
    Rect plotWindow = Offset(tickLabelMargin.left, tickLabelMargin.top) & plotSize;
    Offset offset = Offset(tickLabelMargin.left, tickLabelMargin.top);

    // Since all of the objects in the series use the same marker style,
    // we can calculate the [Paint] objects once and reuse them.
    for (HistogramBins bins in allBins.values) {
      for (int i = 0; i < bins.bins.length; i++) {
        HistogramBin bin = bins.bins[i];
        Rect binRect = bin.toRect(
          axes: axes,
          chartSize: plotSize,
          offset: offset,
          mainAxisAlignment: mainAxisAlignment,
        );

        // Create the painters for the edge and fill of the bin
        Color? fillColor = bin.fillColor;
        Color? edgeColor = bin.edgeColor;
        Paint? paintFill;
        Paint? paintEdge;
        if (fillColor != null) {
          if (selectedBins != null && !selectedBins!.containsBin(i)) {
            fillColor = fillColor.withOpacity(0.5);
          }
          paintFill = Paint()..color = fillColor;
        }
        if (edgeColor != null) {
          paintEdge = Paint()
            ..color = edgeColor
            ..strokeWidth = bin.edgeWidth
            ..style = PaintingStyle.stroke;
        }

        if (binRect.overlaps(plotWindow)) {
          // Paint the bin
          if (paintFill != null) {
            Rect overlap = binRect.intersect(plotWindow);
            canvas.drawRect(
              overlap,
              paintFill,
            );
          }
          // Paint the outline
          if (paintEdge != null) {
            /*AxisAlignedRect alignedPlotWindow = AxisAlignedRect.fromRect(plotWindow, mainAxisAlignment);
            double bin0 = crossTransform.map(0) + crossOffset;
            double clippedBin0 = math.max(bin0, plotWindow.top);

            // Calculate the pixel coordinates of the bin
            double mainStart = mainTransform.map(bin.start) + mainOffset;
            double mainEnd = mainTransform.map(bin.end) + mainOffset;
            double lastCrossEnd = crossTransform.map(lastCount) + crossOffset;
            double crossEnd = crossTransform.map(bin.count) + crossOffset;

            // Clip the outline to the plot window
            double clippedMainStart = math.max(mainStart, alignedPlotWindow.mainStart);
            double clippedMainEnd = math.min(mainEnd, alignedPlotWindow.mainEnd);
            double clippedLastCrossEnd = math.max(lastCrossEnd, alignedPlotWindow.crossStart);
            double clippedCrossEnd = math.min(crossEnd, alignedPlotWindow.crossEnd);
            // Draw the minimum bin side
            if (alignedPlotWindow.inMain(mainStart)) {
              canvas.drawLine(
                alignedPlotWindow.getOffset(mainStart, clippedLastCrossEnd),
                alignedPlotWindow.getOffset(mainStart, clippedCrossEnd),
                paintEdge,
              );
            }
            // Draw the top/bottom
            if (alignedPlotWindow.inCross(crossEnd)) {
              canvas.drawLine(
                alignedPlotWindow.getOffset(clippedMainStart, crossEnd),
                alignedPlotWindow.getOffset(clippedMainEnd, crossEnd),
                paintEdge,
              );
            }

            // Draw the maximum bin side
            double nextCount = i < bins.bins.length - 1 ? bins.bins[i + 1].count.toDouble() : 0;
            if (i == bins.bins.length - 1 && alignedPlotWindow.inMain(mainEnd) || nextCount == 0) {
              canvas.drawLine(
                alignedPlotWindow.getOffset(mainEnd, clippedCrossEnd),
                alignedPlotWindow.getOffset(mainEnd, clippedBin0),
                paintEdge,
              );
            }*/
          }
        }
        // Draw the bottom of the bins
        /*if (alignedPlotWindow.inCross(bin0) && paintEdge != null) {
          double clippedMin = math.max(mainMin, alignedPlotWindow.mainStart);
          double clippedMax = math.min(mainMax, alignedPlotWindow.mainEnd);
          canvas.drawLine(
            alignedPlotWindow.getOffset(clippedMin, bin0),
            alignedPlotWindow.getOffset(clippedMax, bin0),
            paintEdge,
          );
        }*/
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // TODO: imporve repaint logic
    return true;
  }
}

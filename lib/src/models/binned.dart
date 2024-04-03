import 'package:flutter/material.dart';
import 'package:rubin_chart/src/models/axes/axes.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/ui/chart.dart';

/// The different types of aggregation that can be used in a histogram.
enum BinAggregationType {
  count,
  sum,
  mean,
  median,
  min,
  max,
}

/// A class that represents binned data.
abstract class BinnedData {
  Map<Object, List<double>> data;
  double mainStart;
  double mainEnd;
  final Color? fillColor;
  final Color? edgeColor;
  final double edgeWidth;

  BinnedData({
    required this.data,
    required this.mainStart,
    required this.mainEnd,
    this.fillColor,
    this.edgeColor,
    this.edgeWidth = 1,
  });

  void insert(Object dataId, List<double> data);

  bool contains(List<double> data);

  Rect rectToPixel({
    required ChartAxes axes,
    required Size chartSize,
    required AxisOrientation mainAxisAlignment,
    Offset offset = Offset.zero,
  });

  /// The number of data points in the bin.
  int get count => data.length;
}

/// A class that represents a container for binned data.
class BinnedDataContainer {
  final List<BinnedData> bins;

  /// The number of data points that did not fit into any bin.
  int missingData = 0;

  BinnedDataContainer({required this.bins});

  /// Insert a data point into the histogram.
  bool insert(Object key, List<double> data) {
    for (BinnedData bin in bins) {
      if (bin.contains(data)) {
        bin.insert(key, data);
        return true;
      }
    }
    // The data point did not fit into any bin.
    missingData++;
    return false;
  }

  /// Insert a list of data points into the histogram.
  /// The number of data points that did not fit into any bin is returned.
  int insertAll(Map<Object, List<double>> data) {
    for (MapEntry<Object, List<double>> entry in data.entries) {
      insert(entry.key, entry.value);
    }
    return missingData;
  }
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
  List<BinnedData> getBins(Map<BigInt, BinnedDataContainer> binContainers) {
    if (endBinIndex == null) {
      return [binContainers[seriesIndex]!.bins[startBinIndex]];
    }
    return binContainers[seriesIndex]!.bins.sublist(startBinIndex, endBinIndex);
  }

  /// Returns a list of selected data IDs within the selected range of bins.
  Set<Object> getSelectedDataIds(Map<BigInt, BinnedDataContainer> binContainers) {
    Set<Object> dataIds = {};
    for (BinnedData bin in getBins(binContainers)) {
      dataIds.addAll(bin.data.keys);
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

class BinnedSelectionDetails {
  final List<BinnedData> selectedBins;
  final Set<Object> selectedDataPoints;

  BinnedSelectionDetails(this.selectedBins, this.selectedDataPoints);
}

typedef BinnedSelectionCallback = void Function({required BinnedSelectionDetails details});

class BinnedChartInfo extends ChartInfo {
  /// The number of bins to use
  /// Either [nBins] or [edges] must be provided.
  final int? nBins;

  /// Whether to fill the bins or leave them as outlines.
  final bool doFill;

  /// The bins to use for the histogram.
  /// Either nBins or bins must be provided.
  final List<double>? edges;

  /// Callback for when a bin is selected.
  final BinnedSelectionCallback? onSelection;

  BinnedChartInfo({
    required super.id,
    required super.allSeries,
    required super.builder,
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
    this.onSelection,
  }) : assert(nBins != null || edges != null);
}

class BinnedChart extends StatefulWidget {
  final BinnedChartInfo info;
  final SelectionController? selectionController;
  final Map<AxisId, AxisController> axisControllers;
  final List<AxisId> hiddenAxes;
  final AxisOrientation? mainAxisAlignment;

  const BinnedChart({
    super.key,
    required this.info,
    this.selectionController,
    this.axisControllers = const {},
    this.hiddenAxes = const [],
    this.mainAxisAlignment,
  });

  @override
  BinnedChartState createState() => BinnedChartState();

  static Widget builder({
    required ChartInfo info,
    Map<AxisId, AxisController>? axisControllers,
    SelectionController? selectionController,
    List<AxisId>? hiddenAxes,
  }) {
    return BinnedChart(
      info: info as BinnedChartInfo,
      selectionController: selectionController,
      axisControllers: axisControllers ?? {},
      hiddenAxes: hiddenAxes ?? [],
    );
  }
}

abstract class BinnedChartState extends State<BinnedChart> with ChartMixin, Scrollable2DChartMixin {
  AxisOrientation get mainAxisAlignment;

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

  final Map<BigInt, BinnedDataContainer> _binContainers = {};

  SelectedBinRange? selectedBins;

  /// The location of the base of the histogram bins.
  /// This is used to determine the orientation and layout of the histogram.
  late AxisLocation baseLocation;

  @override
  void didUpdateWidget(BinnedChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initBins();
  }

  @override
  void initState() {
    super.initState();
    // Add key detector
    focusNode.addListener(focusNodeListener);

    // Subscribe to the selection controller
    if (widget.selectionController != null) {
      widget.selectionController!.subscribe((Set<Object> dataPoints) {
        selectedDataPoints = dataPoints;
        setState(() {});
      });
    }

    // Initialize the axes and bins
    initAxesAndBins();
  }

  void initAxesAndBins() {
    _initAxes();
    _initBins();
  }

  void _initAxes() {
    // Populate the axis controllers
    axisControllers.addAll(widget.axisControllers.values);

    // Initialize the axes
    _axes.addAll(widget.info.initializeAxes());

    // Initialize the axis controllers
    for (ChartAxes axes in _axes.values) {
      for (ChartAxis axis in axes.axes.values) {
        if (widget.axisControllers.containsKey(axis.info.axisId)) {
          axis.controller = widget.axisControllers[axis.info.axisId];
        }
        if (widget.hiddenAxes.contains(axis.info.axisId)) {
          axis.showLabels = false;
        }
      }
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

  void _initBins() {
    // Clear the parameters
    _binContainers.clear();

    ChartAxis mainAxis;
    int mainCoordIdx;
    if (widget.info.mainAxisAlignment == AxisOrientation.horizontal) {
      mainAxis = _axes.values.first.axes.values.first;
      mainCoordIdx = 0;
    } else {
      mainAxis = _axes.values.first.axes.values.last;
      mainCoordIdx = 1;
    }
    ChartAxes axes = _axes.values.first;

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
      _binContainers[series.id] = BinnedDataContainer(
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
        _binContainers[series.id]!.insert(entry.key, coords);
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
            painter: BoxChartPainter(
              mainAxisAlignment: mainAxisAlignment,
              axes: _axes[series.axesId]!,
              errorBars: series.errorBars,
              binContainers: _binContainers,
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
        selectedDataPoints = selectedBins!.getSelectedDataIds(_binContainers);
      }
    } else {
      selectedBins = null;
    }

    // Update the selection controller if available
    if (widget.selectionController != null) {
      widget.selectionController!.updateSelection(widget.info.id, selectedDataPoints);
    }

    // Call the selection callback if available
    if (widget.info.onSelection != null) {
      widget.info.onSelection!(
          details: BinnedSelectionDetails(selectedBins?.getBins(_binContainers) ?? [], selectedDataPoints));
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

    for (MapEntry<BigInt, BinnedDataContainer> entry in _binContainers.entries) {
      BigInt seriesIndex = entry.key;
      BinnedDataContainer bins = entry.value;
      for (int i = 0; i < bins.bins.length; i++) {
        BinnedData bin = bins.bins[i];
        Rect binRect = bin.rectToPixel(
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

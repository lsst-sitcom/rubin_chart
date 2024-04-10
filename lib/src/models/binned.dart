import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rubin_chart/src/models/axes/axes.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/marker.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/ui/axis_painter.dart';
import 'package:rubin_chart/src/ui/chart.dart';
import 'package:rubin_chart/src/ui/charts/box.dart';
import 'package:rubin_chart/src/ui/charts/cartesian.dart';

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

abstract class BinnedChart extends StatefulWidget {
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
  BinnedChartState createState();
}

abstract class BinnedChartState<T extends BinnedChart> extends State<T>
    with ChartMixin, Scrollable2DChartMixin {
  AxisOrientation get mainAxisAlignment;

  BinnedChartInfo get info;

  @override
  SeriesList get seriesList => SeriesList(
        widget.info.allSeries,
        widget.info.colorCycle ?? widget.info.theme.colorCycle,
      );

  /// The axes of the chart.
  @override
  Map<Object, ChartAxes> get allAxes => _axes;

  /// The axes of the chart.
  final Map<Object, ChartAxes> _axes = {};

  final Map<BigInt, BinnedDataContainer> binContainers = {};

  SelectedBinRange? selectedBins;

  /// The location of the base of the histogram bins.
  /// This is used to determine the orientation and layout of the histogram.
  late AxisLocation baseLocation;

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    updateAxesAndBins();
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

  void initAxesAndBins();

  void updateAxesAndBins();

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
            painter: BinnedChartPainter(
              mainAxisAlignment: mainAxisAlignment,
              axes: _axes[series.axesId]!,
              errorBars: series.errorBars,
              binContainers: binContainers,
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
              child: SizedBox(
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
        selectedDataPoints = selectedBins!.getSelectedDataIds(binContainers);
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
          details: BinnedSelectionDetails(selectedBins?.getBins(binContainers) ?? [], selectedDataPoints));
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

    for (MapEntry<BigInt, BinnedDataContainer> entry in binContainers.entries) {
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

/// A painter for a collection of histograms.
class BinnedChartPainter extends CustomPainter {
  /// The axes of the plot, used to project the markers onto the plot.
  final ChartAxes axes;

  /// The bins to draw
  final Map<BigInt, BinnedDataContainer> binContainers;

  /// The error bar style used for the series.
  final ErrorBars? errorBars;

  /// Offset from the lower left to make room for labels.
  final EdgeInsets tickLabelMargin;

  /// (Optional) selected bin
  final SelectedBinRange? selectedBins;

  /// Orientation of the main axis
  final AxisOrientation mainAxisAlignment;

  BinnedChartPainter({
    required this.axes,
    required this.mainAxisAlignment,
    required this.errorBars,
    required this.binContainers,
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
    for (BinnedDataContainer bins in binContainers.values) {
      for (int i = 0; i < bins.bins.length; i++) {
        BinnedData bin = bins.bins[i];
        Rect binRect = bin.rectToPixel(
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
        Paint paintWhisker = paintEdge ?? Paint()
          ..color = Colors.black
          ..strokeWidth = 2;

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

        if (selectedBins != null && !selectedBins!.containsBin(i)) {
          paintWhisker.color = paintWhisker.color.withOpacity(0.5);
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

        if (bin is BoxChartBox) {
          if (bin.count == 0) {
            continue;
          }
          // Draw the whiskers
          Offset minWhiskerStart;
          Offset minWhiskerEnd;
          Offset minSerifStart;
          Offset minSerifEnd;
          Offset maxWhiskerStart;
          Offset maxWhiskerEnd;
          Offset maxSerifStart;
          Offset maxSerifEnd;
          Offset medianStart;
          Offset medianEnd;
          if (mainAxisAlignment == AxisOrientation.horizontal) {
            // Calculate the midpoint of the main axis.
            // We use projections since the x scale might be non-linear.
            minSerifStart = axes.doubleToPixel([bin.mainStart, bin.min], plotSize);
            minSerifEnd = axes.doubleToPixel([bin.mainEnd, bin.min], plotSize);
            double midpointPx = (minSerifEnd.dx + minSerifStart.dx) / 2;
            double midpoint = axes.doubleFromPixel(Offset(midpointPx, minSerifStart.dy), plotSize)[0];
            minWhiskerStart = Offset(midpointPx, minSerifStart.dy);
            minWhiskerEnd = axes.doubleToPixel([midpoint, bin.quartile1], plotSize);

            maxSerifStart = axes.doubleToPixel([bin.mainStart, bin.max], plotSize);
            maxSerifEnd = axes.doubleToPixel([bin.mainEnd, bin.max], plotSize);
            maxWhiskerStart = Offset(midpointPx, maxSerifStart.dy);
            maxWhiskerEnd = axes.doubleToPixel([midpoint, bin.quartile3], plotSize);

            medianStart = axes.doubleToPixel([bin.mainStart, bin.median], plotSize);
            medianEnd = axes.doubleToPixel([bin.mainEnd, bin.median], plotSize);
          } else {
            minSerifStart = axes.doubleToPixel([bin.min, bin.mainStart], plotSize);
            minSerifEnd = axes.doubleToPixel([bin.min, bin.mainEnd], plotSize);
            double midpointPx = (minSerifEnd.dy + minSerifStart.dy) / 2;
            double midpoint = axes.doubleFromPixel(Offset(minSerifStart.dx, midpointPx), plotSize)[1];
            minWhiskerStart = Offset(minSerifStart.dx, midpointPx);
            minWhiskerEnd = axes.doubleToPixel([bin.quartile1, midpoint], plotSize);

            maxSerifStart = axes.doubleToPixel([bin.max, bin.mainStart], plotSize);
            maxSerifEnd = axes.doubleToPixel([bin.max, bin.mainEnd], plotSize);
            maxWhiskerStart = Offset(maxSerifStart.dx, midpointPx);
            maxWhiskerEnd = axes.doubleToPixel([bin.quartile3, midpoint], plotSize);

            medianStart = axes.doubleToPixel([bin.median, bin.mainStart], plotSize);
            medianEnd = axes.doubleToPixel([bin.median, bin.mainEnd], plotSize);
          }
          canvas.drawLine(minSerifStart + offset, minSerifEnd + offset, paintWhisker);
          canvas.drawLine(maxSerifStart + offset, maxSerifEnd + offset, paintWhisker);
          canvas.drawLine(minWhiskerStart + offset, minWhiskerEnd + offset, paintWhisker);
          canvas.drawLine(maxWhiskerStart + offset, maxWhiskerEnd + offset, paintWhisker);
          canvas.drawLine(medianStart + offset, medianEnd + offset,
              paintWhisker..strokeWidth = paintWhisker.strokeWidth * 1.5);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // TODO: imporve repaint logic
    return true;
  }
}

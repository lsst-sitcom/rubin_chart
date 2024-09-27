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

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rubin_chart/src/models/axes/axes.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/marker.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/ui/axis_painter.dart';
import 'package:rubin_chart/src/ui/chart.dart';
import 'package:rubin_chart/src/ui/charts/box.dart';
import 'package:rubin_chart/src/ui/charts/cartesian.dart';

/// A class that represents binned data.
abstract class BinnedData {
  /// The data in the bin mapped from the data ID to each data point.
  Map<Object, List<double>> data;

  /// The first value of the main axis.
  double mainStart;

  /// The last value of the main axis.
  double mainEnd;

  /// The color to fill the bin with.
  final Color? fillColor;

  /// The color to outline the bin with.
  final Color? edgeColor;

  /// The width of the outline of the bin.
  final double edgeWidth;

  BinnedData({
    required this.data,
    required this.mainStart,
    required this.mainEnd,
    this.fillColor,
    this.edgeColor,
    this.edgeWidth = 1,
  });

  /// Insert a data point into the bin.
  void insert(Object dataId, List<double> data);

  /// Returns true if the bin contains the given data point.
  bool contains(List<double> data);

  /// Returns a [Rect] that represents the bin in pixel coordinates.
  Rect rectToPixel({
    required ChartAxes axes,
    required Size chartSize,
    required AxisOrientation mainAxisAlignment,
    Offset offset = Offset.zero,
  });

  /// The number of data points in the bin.
  int get count => data.length;

  @override
  String toString() {
    return "BinnedData($mainStart-$mainEnd: ${data.length})";
  }
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

  @override
  String toString() {
    return "BinnedDataContainer($bins)";
  }
}

/// Represents a selected bin in a histogram chart.
class SelectedBin {
  /// Index of the series that the bin belongs to.
  final Object seriesIndex;

  /// Index of this bin in the series.
  final int binIndex;

  SelectedBin(this.seriesIndex, this.binIndex);

  @override
  String toString() => "SelectedBin($seriesIndex-$binIndex)";
}

/// Represents a selected range of bins in a histogram chart.
class SelectedBinRange {
  /// Index of the [Series] that the bins belong to.
  final Object seriesIndex;

  /// First bin index in the range.
  int startBinIndex;

  /// Last bin index in the range.
  int? endBinIndex;

  SelectedBinRange(this.seriesIndex, this.startBinIndex, this.endBinIndex);

  /// Returns a list of [HistogramBin] objects within the selected range of bins.
  List<BinnedData> getBins(Map<Object, BinnedDataContainer> binContainers) {
    if (endBinIndex == null) {
      return [binContainers[seriesIndex]!.bins[startBinIndex]];
    }
    return binContainers[seriesIndex]!.bins.sublist(startBinIndex, endBinIndex);
  }

  /// Returns a list of selected data IDs within the selected range of bins.
  Set<Object> getSelectedDataIds(Map<Object, BinnedDataContainer> binContainers) {
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

  @override
  String toString() => "SelectedBinRange($seriesIndex-$startBinIndex-${endBinIndex ?? ""})";
}

/// Represents the details of a selection in a binned chart.
class BinnedSelectionDetails {
  /// The selected bins.
  final List<BinnedData> selectedBins;

  /// The selected data points contained in the selected bins.
  final Set<Object> selectedDataPoints;

  const BinnedSelectionDetails(this.selectedBins, this.selectedDataPoints);
}

/// A callback for when a bin is selected.
typedef BinnedSelectionCallback = void Function({required BinnedSelectionDetails details});

/// Information for a binned chart.
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

  /// Callback for when a bin is drilled down into.
  final BinnedSelectionCallback? onDrillDown;

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
    this.onDrillDown,
  }) : assert(nBins != null || edges != null);
}

/// A chart based on binned data.
abstract class BinnedChart extends StatefulWidget {
  /// The information for the chart.
  final BinnedChartInfo info;

  /// The selection controller for the chart to synch selection with other charts.
  final SelectionController? selectionController;

  /// The drill down controller for the chart to drill down on other charts.
  final SelectionController? drillDownController;

  /// The controllers for the axes of the chart to synch aligned axes.
  final Map<AxisId, AxisController> axisControllers;

  /// Axes that should be hidden (usually when sharing an axis with another chart).
  final List<AxisId> hiddenAxes;

  /// The main axis alignment for the chart.
  final AxisOrientation? mainAxisAlignment;

  /// Callback for when the cursor moves to a new coordinate.
  final CoordinateCallback? onCoordinateUpdate;

  // Controller for resetting the chart.
  final StreamController<ResetChartAction>? resetController;

  const BinnedChart({
    super.key,
    required this.info,
    this.selectionController,
    this.drillDownController,
    this.axisControllers = const {},
    this.hiddenAxes = const [],
    this.mainAxisAlignment,
    this.onCoordinateUpdate,
    this.resetController,
  });

  @override
  BinnedChartState createState();
}

/// The state for a [BinnedChart].
abstract class BinnedChartState<T extends BinnedChart> extends State<T>
    with ChartMixin, Scrollable2DChartMixin {
  /// The orientation of the main axis.
  AxisOrientation get mainAxisAlignment;

  /// The [BinnedChartInfo] for the chart.
  BinnedChartInfo get info;

  /// The tooltip if the user is hovering over a bin.
  OverlayEntry? hoverOverlay;

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

  /// The collection of bins.
  final Map<Object, BinnedDataContainer> binContainers = {};

  /// The selected bins.
  SelectedBinRange? selectedBins;

  /// A timer used to determine if the user is hovering over a bin.
  Timer? _hoverTimer;

  /// Whether the user is currently hovering over a bin.
  bool _isHovering = false;

  /// The location of the base of the histogram bins.
  /// This is used to determine the orientation and layout of the histogram.
  late AxisLocation baseLocation;

  /// Update the axes and bins if the data changes.
  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.info.allSeries.length == oldWidget.info.allSeries.length &&
        widget.info.nBins == oldWidget.info.nBins) {
      for (int i = 0; i < widget.info.allSeries.length; i++) {
        if (widget.info.allSeries[i].data != oldWidget.info.allSeries[i].data) {
          updateAxesAndBins();
          break;
        }
      }
    } else {
      updateAxesAndBins();
    }
  }

  void _selectDatapoints(Set<Object> dataPoints) {
    selectedDataPoints = dataPoints;
    setState(() {});
  }

  @override
  void dispose() {
    focusNode.removeListener(focusNodeListener);
    if (widget.selectionController != null) {
      widget.selectionController!.unsubscribe(_selectDatapoints);
    }
    if (widget.resetController != null) {
      widget.resetController!.close();
    }
    super.dispose();
  }

  /// Initialize the state by initializing the controllers, axes, and bins.
  @override
  void initState() {
    super.initState();
    // Add key detector
    focusNode.addListener(focusNodeListener);

    // Subscribe to the selection controller
    if (widget.selectionController != null) {
      widget.selectionController!.subscribe(_selectDatapoints);
    }

    // Initialize the reset controller
    if (widget.resetController != null) {
      widget.resetController!.stream.listen((event) {
        initAxesAndBins();
        setState(() {});
      });
    }

    // Initialize the axes and bins
    initAxesAndBins();
  }

  /// Initialize the axes and bins for the chart.
  void initAxesAndBins();

  /// Update the axes and bins for the chart.
  void updateAxesAndBins();

  /// Get the tooltip widget for the given bin.
  /// This is not implemented in the base class because
  /// histograms and box charts have different tooltips.
  Widget getTooltip({
    required PointerHoverEvent event,
    required ChartAxis mainAxis,
    required ChartAxis crossAxis,
    required BinnedData bin,
  });

  /// Create the tooltip if the user is hovering over a bin
  void onHoverStart({required PointerHoverEvent event, BinnedData? bin}) {
    if (bin == null) return;
    ChartAxis mainAxis;
    ChartAxis crossAxis;
    if (mainAxisAlignment == AxisOrientation.horizontal) {
      mainAxis = allAxes.values.first.axes.values.first;
      crossAxis = allAxes.values.first.axes.values.last;
    } else {
      mainAxis = allAxes.values.first.axes.values.last;
      crossAxis = allAxes.values.first.axes.values.first;
    }

    Widget tooltip = getTooltip(
      event: event,
      bin: bin,
      mainAxis: mainAxis,
      crossAxis: crossAxis,
    );

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset globalPosition = renderBox.localToGlobal(event.localPosition);

    hoverOverlay = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: globalPosition.dx,
          top: globalPosition.dy,
          child: Material(
            color: Colors.transparent,
            child: MouseRegion(
              onHover: (PointerHoverEvent event) {
                _clearHover();
              },
              child: tooltip,
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(hoverOverlay!);
  }

  /// Callback for when the user stops hovering over a bin.
  void onHoverEnd(PointerHoverEvent event) {}

  /// Clear the hover overlay and other properties related to hovering
  /// if the user is no longer hovering over a bin.
  void _clearHover() {
    _hoverTimer?.cancel();
    _hoverTimer = null;
    _isHovering = false;
    hoverOverlay?.remove();
    hoverOverlay = null;
    setState(() {});
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
          child: MouseRegion(
              onHover: (PointerHoverEvent event) {
                // In Flutter web this is triggered when the mouse is moved,
                // so we need to keep track of the hover timer manually.

                // Restart the hover timer
                _hoverTimer?.cancel();
                _hoverTimer = Timer(const Duration(milliseconds: 1000), () {
                  SelectedBin? hoverBin = _getBinOnTap(event.localPosition, axisPainter);
                  if (hoverBin == null) {
                    _clearHover();
                    return;
                  }
                  BinnedData bin = binContainers[hoverBin.seriesIndex]!.bins[hoverBin.binIndex];
                  onHoverStart(event: event, bin: bin);
                  _hoverTimer?.cancel();
                  _hoverTimer = null;
                  _isHovering = true;
                  setState(() {});
                });

                if (_isHovering) {
                  _clearHover();
                  onHoverEnd(event);
                }
                _isHovering = false;
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (TapUpDetails details) {
                  _onTapUp(details, axisPainter);
                },
                child: SizedBox(
                  child: Stack(children: children),
                ),
              )),
        ));
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
    _updatedBinSelection(selectedBin);
  }

  /// Update the selected bins based on the currently selected bin.
  void _updatedBinSelection(SelectedBin? selectedBin) {
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
    if (widget.drillDownController != null) {
      widget.drillDownController!.updateSelection(widget.info.id, selectedDataPoints);
    }

    // Call the selection callback if available
    if (widget.info.onSelection != null) {
      widget.info.onSelection!(
          details: BinnedSelectionDetails(selectedBins?.getBins(binContainers) ?? [], selectedDataPoints));
    }

    // Call the drill down callback if available
    if (widget.info.onDrillDown != null) {
      widget.info.onDrillDown!(
          details: BinnedSelectionDetails(selectedBins?.getBins(binContainers) ?? [], selectedDataPoints));
    }
    setState(() {});
  }

  /// Returns the selected bin based on the tap location.
  SelectedBin? _getBinOnTap(Offset location, AxisPainter axisPainter) {
    if (_axes.isEmpty) {
      return null;
    }
    EdgeInsets tickLabelMargin = EdgeInsets.only(
      left: axisPainter.margin.left + axisPainter.tickPadding,
      right: axisPainter.margin.right + axisPainter.tickPadding,
      top: axisPainter.margin.top + axisPainter.tickPadding,
      bottom: axisPainter.margin.bottom + axisPainter.tickPadding,
    );
    Offset offset = Offset(tickLabelMargin.left, tickLabelMargin.top);
    ChartAxes axes = _axes.values.first;

    for (MapEntry<Object, BinnedDataContainer> entry in binContainers.entries) {
      Object seriesIndex = entry.key;
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

  /// Handle a key event.
  /// Override the default to allow arrow keys for navigation
  @override
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      setState(() {
        if (event.logicalKey == LogicalKeyboardKey.keyX ||
            event.logicalKey == LogicalKeyboardKey.keyY ||
            isShiftKey(event.logicalKey)) {
          scaleShiftKey = event.logicalKey;
        }
        if (isShiftKey(event.logicalKey)) {
          scaleShiftKey = event.logicalKey;
        }
      });
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (selectedBins != null && selectedBins!.endBinIndex == null) {
          int nextBin = selectedBins!.startBinIndex - 1;
          if (nextBin < 0) {
            nextBin = binContainers[selectedBins!.seriesIndex]!.bins.length - 1;
          }
          SelectedBin selectedBin = SelectedBin(selectedBins!.seriesIndex, nextBin);
          _updatedBinSelection(selectedBin);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (selectedBins != null && selectedBins!.endBinIndex == null) {
          int nextBin = selectedBins!.startBinIndex + 1;
          if (nextBin >= binContainers[selectedBins!.seriesIndex]!.bins.length) {
            nextBin = 0;
          }
          SelectedBin selectedBin = SelectedBin(selectedBins!.seriesIndex, nextBin);
          _updatedBinSelection(selectedBin);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {}
      setState(() {
        scaleShiftKey = null;
      });
    }
    return KeyEventResult.ignored;
  }
}

/// A painter for a collection of histograms.
class BinnedChartPainter extends CustomPainter {
  /// The axes of the plot, used to project the markers onto the plot.
  final ChartAxes axes;

  /// The bins to draw
  final Map<Object, BinnedDataContainer> binContainers;

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

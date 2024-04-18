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
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rubin_chart/src/models/axes/axes.dart';

import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/ticks.dart';
import 'package:rubin_chart/src/models/marker.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/ui/axis_painter.dart';
import 'package:rubin_chart/src/ui/chart.dart';
import 'package:rubin_chart/src/ui/series_painter.dart';
import 'package:rubin_chart/src/utils/quadtree.dart';
import 'package:rubin_chart/src/utils/utils.dart';

/// Information needed to build a scatter plot.
abstract class ScatterPlotInfo extends ChartInfo {
  ScatterPlotInfo({
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
  }) : super(builder: ScatterPlot.builder);

  /// Function to initialize the axes of the chart.
  Map<Object, ChartAxes> initializeAxes({required Set<Object> drillDownDataPoints});

  /// Function to initialize the axes painter of the chart.
  AxisPainter initializeAxesPainter({required Map<Object, ChartAxes> allAxes, required ChartTheme theme});
}

/// A scatter plot.
class ScatterPlot extends StatefulWidget {
  /// The information needed to build the scatter plot.
  final ScatterPlotInfo info;

  /// The selection controller for the chart.
  final SelectionController? selectionController;

  /// The drill down controller for the chart.
  final SelectionController? drillDownController;

  /// The axis controllers for the chart.
  final Map<AxisId, AxisController> axisControllers;

  /// The hidden axes for the chart.
  final List<AxisId> hiddenAxes;

  /// Callback function for when the cursor is moved to new coordinates.
  final CoordinateCallback? onCoordinateUpdate;

  const ScatterPlot({
    Key? key,
    required this.info,
    this.selectionController,
    this.drillDownController,
    this.axisControllers = const {},
    this.hiddenAxes = const [],
    this.onCoordinateUpdate,
  }) : super(key: key);

  /// Create a scatter plot.
  static Widget builder({
    required ChartInfo info,
    Map<AxisId, AxisController>? axisControllers,
    SelectionController? selectionController,
    SelectionController? drillDownController,
    List<AxisId>? hiddenAxes,
    CoordinateCallback? onCoordinateUpdate,
  }) {
    if (info is! ScatterPlotInfo) {
      throw ArgumentError("ScatterPlot.builder: info must be of type ScatterPlotInfo");
    }
    return ScatterPlot(
      info: info,
      selectionController: selectionController,
      drillDownController: drillDownController,
      axisControllers: axisControllers ?? {},
      hiddenAxes: hiddenAxes ?? [],
      onCoordinateUpdate: onCoordinateUpdate,
    );
  }

  @override
  ScatterPlotState createState() => ScatterPlotState();
}

/// A data point that is being hovered over.
class HoverDataPoint {
  /// The ID of the [ChartAxes] containing the data point.
  final Object chartAxesId;

  /// The ID of the data point.
  final Object dataId;

  const HoverDataPoint(this.chartAxesId, this.dataId);
}

/// The state of a [ScatterPlot].
class ScatterPlotState extends State<ScatterPlot> with ChartMixin, Scrollable2DChartMixin {
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

  /// Quadtree for the bottom left axes.
  final Map<Object, QuadTree<Object>> _quadTrees = {};

  /// The tooltip overlay.
  OverlayEntry? hoverOverlay;

  /// Timer to keep track of whether or not the cursor is hovering over a point.
  Timer? _hoverTimer;

  /// Whether or not the cursor is hovering over a point.
  bool _isHovering = false;

  /// Clear the timer and all other hover data.
  void _clearHover() {
    _hoverTimer?.cancel();
    _hoverTimer = null;
    _isHovering = false;
    hoverOverlay?.remove();
    hoverOverlay = null;
    setState(() {});
  }

  /// Notify the user that the cursor is no longer over the chart.
  void onHoverEnd(PointerExitEvent event) {
    if (widget.onCoordinateUpdate != null) {
      widget.onCoordinateUpdate!({});
    }
  }

  /// Create a tooltip when the cursor is hovering over a point.
  void onHoverStart({required PointerHoverEvent event, required Map<Object, dynamic> data}) {
    Widget tooltip = getTooltip(
      data: data,
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

  /// Build the tooltip.
  Widget getTooltip({required Map<Object, dynamic> data}) {
    List<Widget> tooltipData = [];
    for (MapEntry<Object, dynamic> entry in data.entries) {
      tooltipData.add(Text("${entry.key}: ${entry.value.toStringAsFixed(3)}"));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: tooltipData,
      ),
    );
  }

  /// Initialize the axes based on the [Series] and potentially
  /// drilled down data points in the chart.
  void _initializeAxes() {
    // Initialize the axes
    _axes.addAll(widget.info.initializeAxes(drillDownDataPoints: drillDownDataPoints));

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

  /// Initialize the quadtree used for selection.
  void _initializeQuadTree() {
    List<Object> axesIndices = _axes.keys.toList();
    for (Object axesIndex in axesIndices) {
      ChartAxes axes = _axes[axesIndex]!;
      Rect linearRect = axes.linearRect;
      _quadTrees[axesIndex] = QuadTree(
        maxDepth: widget.info.theme.quadTreeDepth,
        capacity: widget.info.theme.quadTreeCapacity,
        contents: [],
        children: [],
        left: linearRect.left,
        top: linearRect.top,
        width: linearRect.width,
        height: linearRect.height,
      );
    }

    // Populate the quadtrees
    for (Series series in widget.info.allSeries) {
      ChartAxes axes = _axes[series.axesId]!;
      AxisId axisId0 = axes.axes.keys.first;
      AxisId axisId1 = axes.axes.keys.last;

      dynamic columnX = series.data.data[series.data.plotColumns[axisId0]]!.values.toList();
      dynamic columnY = series.data.data[series.data.plotColumns[axisId1]]!.values.toList();

      for (int i = 0; i < series.data.length; i++) {
        dynamic seriesX = columnX[i];
        dynamic seriesY = columnY[i];
        Offset point = axes.dataToLinear([seriesX, seriesY]);

        _quadTrees[series.axesId]!.insert(
          series.data.data[series.data.plotColumns.values.first]!.keys.toList()[i],
          point,
        );
      }
    }
  }

  /// Update the selection data points.
  void _onSelectionUpdate(Set<Object> dataPoints) {
    selectedDataPoints = dataPoints;
    setState(() {});
  }

  /// If drill down is enabled, zoom in to the selected data points
  /// from another chart.
  void _onDrillDownUpdate(Set<Object> dataPoints) {
    drillDownDataPoints = dataPoints;
    if (widget.info.zoomOnDrillDown) {
      _axes.clear();
      _initializeAxes();
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // Add key detector
    focusNode.addListener(focusNodeListener);

    // Add the axis controllers to the list of controllers
    axisControllers.addAll(widget.axisControllers.values);

    // Initialize selection controller
    if (widget.selectionController != null) {
      widget.selectionController!.subscribe(_onSelectionUpdate);
    }

    //Initialize drill down controller
    if (widget.drillDownController != null) {
      widget.drillDownController!.subscribe(_onDrillDownUpdate);
    }

    // Initialize the axes
    _initializeAxes();

    // Initialize the quadtrees
    _initializeQuadTree();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];

    AxisPainter axisPainter = widget.info.initializeAxesPainter(
      allAxes: _axes,
      theme: widget.info.theme,
    );

    // Draw the axes
    children.add(
      Positioned.fill(
        child: CustomPaint(
          painter: axisPainter,
        ),
      ),
    );

    // Add a SeriesPainter widget for each [Series].
    int colorIndex = 0;
    for (int i = 0; i < seriesList.length; i++) {
      if (colorIndex >= widget.info.theme.colorCycle.length) {
        colorIndex = 0;
      }
      Series series = seriesList[i];
      Marker marker = series.marker ?? Marker(color: widget.info.theme.colorCycle[colorIndex++]);
      children.add(
        Positioned.fill(
          child: CustomPaint(
            painter: SeriesPainter(
              axes: _axes[series.axesId]!,
              marker: marker,
              errorBars: series.errorBars,
              data: series.data,
              tickLabelMargin: EdgeInsets.only(
                left: axisPainter.margin.left + axisPainter.tickPadding,
                right: axisPainter.margin.right + axisPainter.tickPadding,
                top: axisPainter.margin.top + axisPainter.tickPadding,
                bottom: axisPainter.margin.bottom + axisPainter.tickPadding,
              ),
              selectedDataPoints: selectedDataPoints,
              drillDownDataPoints: drillDownDataPoints,
            ),
          ),
        ),
      );
    }

    // Add the selection box if the user is dragging
    if (dragging) {
      children.add(Positioned(
        left: math.min(dragStart!.dx, dragEnd!.dx),
        top: math.min(dragStart!.dy, dragEnd!.dy),
        child: Container(
          width: (dragEnd!.dx - dragStart!.dx).abs(),
          height: (dragEnd!.dy - dragStart!.dy).abs(),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.blue,
              width: 2,
            ),
          ),
        ),
      ));
    }

    return Focus(
        focusNode: focusNode,
        //autofocus: true,
        child: Listener(
            onPointerSignal: (PointerSignalEvent event) {
              if (event is PointerScrollEvent) {
                onPan(event, axisPainter);
              } else if (event is PointerScaleEvent) {
                onScale(event, axisPainter);
              }
            },
            child: MouseRegion(
              onExit: (PointerExitEvent event) {
                if (!_isHovering) {
                  _clearHover();
                  onHoverEnd(event);
                }
              },
              onHover: (PointerHoverEvent event) {
                // In Flutter web this is triggered when the mouse is moved,
                // so we need to keep track of the hover timer manually.

                // Restart the hover timer
                _hoverTimer?.cancel();
                _hoverTimer = Timer(const Duration(milliseconds: 1000), () {
                  // See if the cursoer is hovering over a point
                  HoverDataPoint? hoverDataPoint = _onTapUp(event.localPosition, axisPainter, true);
                  if (hoverDataPoint == null) {
                    _clearHover();
                    return;
                  }

                  // Find the full series data for the point that was hovered over
                  Series? hoverSeries;
                  for (Series series in widget.info.allSeries) {
                    if (series.axesId == hoverDataPoint.chartAxesId) {
                      hoverSeries = series;
                      break;
                    }
                  }
                  if (hoverSeries == null) {
                    // This should never happen
                    throw Exception("No series found for axes ${hoverDataPoint.chartAxesId}");
                  }
                  // Extract the series data for the hovered point
                  SeriesData seriesData = hoverSeries.data;
                  Map<Object, dynamic> tooltipData = {};
                  for (Object column in seriesData.plotColumns.values) {
                    tooltipData[column] = seriesData.data[column]![hoverDataPoint.dataId];
                  }

                  // Call the hover start function.
                  onHoverStart(event: event, data: tooltipData);
                  _hoverTimer?.cancel();
                  _hoverTimer = null;
                  _isHovering = true;
                  setState(() {});
                });

                if (_isHovering) {
                  _clearHover();
                }
                _isHovering = false;

                if (widget.onCoordinateUpdate != null) {
                  Map<Object, dynamic> coordinates = {};
                  for (ChartAxes axes in _axes.values) {
                    Offset cursor = event.localPosition;
                    cursor = Offset(cursor.dx - axisPainter.margin.left - axisPainter.tickPadding,
                        cursor.dy - axisPainter.margin.top - axisPainter.tickPadding);
                    List<dynamic> coords = axes.dataFromPixel(cursor, axisPainter.chartSize);
                    for (int i = 0; i < axes.axes.length; i++) {
                      ChartAxis axis = axes.axes.values.elementAt(i);
                      coordinates[axis.info.label] = coords[i];
                    }
                  }
                  widget.onCoordinateUpdate!(coordinates);
                  setState(() {});
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (TapUpDetails details) {
                  _onTapUp(details.localPosition, axisPainter);
                  setState(() {});
                },
                onPanStart: (DragStartDetails details) {
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
                },
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
              ),
            )));
  }

  /// Update the drag parameters when the user starts dragging.
  void _onDragStart(DragStartDetails details, AxisPainter axisPainter) {
    focusNode.requestFocus();
    dragStart = details.localPosition;
    dragEnd = details.localPosition;
    selectedDataPoints.clear();
    setState(() {});
  }

  /// Update the drag region size and select data points within the drag region.
  void _onDragUpdate(DragUpdateDetails details, AxisPainter axisPainter) {
    focusNode.requestFocus();
    dragEnd = details.localPosition;
    Size chartSize = axisPainter.chartSize;

    selectedDataPoints = {};
    for (MapEntry<Object, QuadTree<Object>> entry in _quadTrees.entries) {
      Object axesId = entry.key;
      ChartAxes axes = _axes[axesId]!;
      QuadTree<Object> quadTree = entry.value;
      // Convert the selection area to cartesian coordinates
      double xStart = dragStart!.dx - axisPainter.margin.left - axisPainter.tickPadding;
      double yStart = dragStart!.dy - axisPainter.margin.top - axisPainter.tickPadding;
      double xEnd = dragEnd!.dx - axisPainter.margin.left - axisPainter.tickPadding;
      double yEnd = dragEnd!.dy - axisPainter.margin.top - axisPainter.tickPadding;
      Offset projectedStart = axes.linearFromPixel(pixel: Offset(xStart, yStart), chartSize: chartSize);
      Offset projectedEnd = axes.linearFromPixel(pixel: Offset(xEnd, yEnd), chartSize: chartSize);
      // Select all points in the quadtree that are within the selection area
      selectedDataPoints.addAll(quadTree.queryRect(
        Rect.fromPoints(projectedStart, projectedEnd),
      ));
    }

    if (widget.selectionController != null) {
      widget.selectionController!.updateSelection(null, selectedDataPoints);
    }

    setState(() {});
  }

  /// Clear the drag parameters when the user stops dragging.
  void _onDragEnd(DragEndDetails details, AxisPainter axisPainter) => _cleanDrag();

  /// Clear the drag parameters when the user cancels dragging.
  void _onDragCancel() => _cleanDrag();

  /// Clear the drag parameters.
  void _cleanDrag() {
    dragStart = null;
    dragEnd = null;
    setState(() {});
  }

  /// Get the nearest point to the cursor.
  /// This accounts for possible scaling differences, for example log scaling,
  /// to search within a region.
  QuadTreeElement? _getSelectedPoint(
      Offset location, AxisPainter axisPainter, ChartAxes axes, Size chartSize, QuadTree<Object> quadTree,
      [Offset markerSize = const Offset(10, 10)]) {
    Offset projectedStart = axes.linearFromPixel(pixel: location - markerSize, chartSize: chartSize);
    Offset projectedEnd = axes.linearFromPixel(pixel: location + markerSize, chartSize: chartSize);

    List<QuadTreeElement<Object>> pointsInRegion = quadTree.queryRectElements(
      Rect.fromPoints(projectedStart, projectedEnd),
    );
    Offset linearLocation = axes.linearFromPixel(pixel: location, chartSize: chartSize);
    if (pointsInRegion.isNotEmpty) {
      QuadTreeElement<Object> selectedElement = pointsInRegion.first;
      double dist2 = (selectedElement.center - linearLocation).distanceSquared;
      for (QuadTreeElement<Object> element in pointsInRegion) {
        double elementDist = (element.center - linearLocation).distanceSquared;
        if (elementDist < dist2) {
          selectedElement = element;
          dist2 = elementDist;
        }
      }
      return selectedElement;
    }
    return null;
  }

  /// Check for the nearest data point to the cursor when the user taps the chart.
  /// If [isHover] then the function will return the nearest data point without
  /// updating the selection.
  HoverDataPoint? _onTapUp(Offset localPosition, AxisPainter axisPainter, [bool isHover = false]) {
    focusNode.requestFocus();
    Size chartSize = axisPainter.chartSize;

    QuadTreeElement? nearest;
    Object? nearestChartAxesId;
    for (MapEntry<Object, QuadTree<Object>> entry in _quadTrees.entries) {
      Object axesId = entry.key;
      ChartAxes axes = _axes[axesId]!;
      QuadTree<Object> quadTree = entry.value;
      // Select nearest point in the quadtree.
      double x = localPosition.dx - axisPainter.margin.left - axisPainter.tickPadding;
      double y = localPosition.dy - axisPainter.margin.top - axisPainter.tickPadding;
      QuadTreeElement? localNearest = _getSelectedPoint(Offset(x, y), axisPainter, axes, chartSize, quadTree);
      if (localNearest != null) {
        if (nearest != null) {
          if ((localNearest.center - Offset(x, y)).distanceSquared <
              (nearest.center - Offset(x, y)).distanceSquared) {
            nearest = localNearest;
            nearestChartAxesId = axesId;
          }
        } else {
          nearest = localNearest;
          nearestChartAxesId = axesId;
        }
      }
    }

    if (isHover) {
      if (nearest != null) {
        return HoverDataPoint(nearestChartAxesId!, nearest.element);
      }
    }

    if (nearest == null) {
      selectedDataPoints = {};
    } else {
      selectedDataPoints = {nearest.element};
    }
    if (widget.selectionController != null) {
      widget.selectionController!.updateSelection(null, selectedDataPoints);
    }
    return null;
  }
}

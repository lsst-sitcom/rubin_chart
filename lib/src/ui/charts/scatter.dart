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
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import 'package:rubin_chart/src/ui/selection_controller.dart';

/// Maximum number of scatter points before switching to image caching mode in [SeriesPainter].
const int kMaxScatterPoints = 100000;

/// The action to take when the cursor is moved with the pointer button engaged.
enum CursorAction {
  select,
  drillDown,
  dateTimeSelect,
}

/// Information needed to build a scatter plot.
abstract class ScatterPlotInfo extends ChartInfo {
  final CursorAction cursorAction;
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
    this.cursorAction = CursorAction.select,
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

  /// The reset controller for the chart.
  final StreamController<ResetChartAction>? resetController;

  const ScatterPlot({
    Key? key,
    required this.info,
    this.selectionController,
    this.drillDownController,
    this.axisControllers = const {},
    this.hiddenAxes = const [],
    this.onCoordinateUpdate,
    this.resetController,
  }) : super(key: key);

  /// Create a scatter plot.
  static Widget builder({
    required ChartInfo info,
    Map<AxisId, AxisController>? axisControllers,
    SelectionController? selectionController,
    SelectionController? drillDownController,
    List<AxisId>? hiddenAxes,
    CoordinateCallback? onCoordinateUpdate,
    StreamController<ResetChartAction>? resetController,
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
      resetController: resetController,
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

  final Map<Object, GlobalKey> _seriesKeys = {};
  final Map<Object, SeriesPainter> _seriesPainters = {};

  /// Whether to select points of zoom in.
  CursorAction get cursorAction => widget.info.cursorAction;

  /// Offset due to a user translation.
  /// This is used when the user is panning with a large number of data points to plot.
  Offset translationOffset = Offset.zero;

  double largeDataScale = 1.0;

  /// Number of points to be plotted.
  int nPoints = 0;

  /// Whether or not the user is currently dragging
  bool _isDragging = false;

  /// Whether or not the user is using a drag gesture.
  bool _isDragGesture = false;

  /// Points that are being selected during the current drag operation.
  /// This is separate from the main selection to allow for immediate visual feedback
  /// during drag operations without sending updates to the selection controller.
  Set<Object> _dragSelectedPoints = {};

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
          left: globalPosition.dx + 15,
          top: globalPosition.dy + 15,
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

  @override
  void onAxesUpdate() {
    for (GlobalKey key in _seriesKeys.values) {
      RenderObject renderObject = key.currentContext!.findRenderObject()!;
      if (renderObject is RenderRepaintBoundary) {
        renderObject.markNeedsPaint();
      }
      for (SeriesPainter seriesPainter in _seriesPainters.values) {
        seriesPainter.translationOffset = translationOffset;
        if (translationOffset == Offset.zero) {
          seriesPainter.cachedPicture = null;
        }
      }
    }
  }

  void _markSeriesNeedsUpdate() {
    for (GlobalKey key in _seriesKeys.values) {
      RenderObject renderObject = key.currentContext!.findRenderObject()!;
      if (renderObject is RenderRepaintBoundary) {
        renderObject.markNeedsPaint();
      }
    }
  }

  /// Initialize the axes based on the [Series] and potentially
  /// drilled down data points in the chart.
  void _initializeAxes() {
    _seriesKeys.clear();
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
    translationOffset = Offset.zero;
  }

  /// Initialize the quadtree used for selection.
  void _initializeQuadTree() {
    _quadTrees.clear();
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
    nPoints = 0;
    for (Series series in widget.info.allSeries) {
      ChartAxes axes = _axes[series.axesId]!;
      AxisId axisId0 = axes.axes.keys.first;
      AxisId axisId1 = axes.axes.keys.last;

      dynamic columnX = series.data.data[series.data.plotColumns[axisId0]]!.values.toList();
      dynamic columnY = series.data.data[series.data.plotColumns[axisId1]]!.values.toList();
      List<Object> dataIds = series.data.data[series.data.plotColumns.values.first]!.keys.toList();

      for (int i = 0; i < series.data.length; i++) {
        dynamic seriesX = columnX[i];
        dynamic seriesY = columnY[i];
        Offset point = axes.dataToLinear([seriesX, seriesY]);

        _quadTrees[series.axesId]!.insert(
          dataIds[i],
          point,
        );
        nPoints++;
      }
    }
  }

  /// Update the selection data points.
  void _onSelectionUpdate(Object? origin, Set<Object> dataPoints) {
    // Check if we're receiving our own update
    if (origin == widget.info.id) {
      return;
    }

    // If we're currently dragging, treat this as a temporary selection
    if (_isDragging) {
      // Save the current selection and update the drag selection
      _dragSelectedPoints = Set<Object>.from(dataPoints);
      // Update the UI to show the temporary selection without changing the permanent selection
      _markSeriesForDragSelection();
      return;
    }

    // Regular (non-drag) selection update
    selectedDataPoints = dataPoints;

    _markSeriesNeedsUpdate();
    setState(() {});
  }

  /// If drill down is enabled, zoom in to the selected data points
  /// from another chart.
  void _onDrillDownUpdate(Object? origin, Set<Object> dataPoints) {
    drillDownDataPoints = dataPoints;
    if (widget.info.zoomOnDrillDown) {
      _axes.clear();
      _initializeAxes();
    }
    setState(() {});
  }

  @override
  void dispose() {
    final chartId = widget.info.id;
    // Remove the key detector
    focusNode.removeListener(focusNodeListener);

    // Remove the selection controller
    if (widget.selectionController != null) {
      widget.selectionController!.unsubscribe(chartId);
    }

    // Remove the drill down controller
    if (widget.drillDownController != null) {
      widget.drillDownController!.unsubscribe(chartId);
    }

    // Remove the reset controller
    if (widget.resetController != null) {
      widget.resetController!.close();
    }

    super.dispose();
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
      widget.selectionController!.subscribe(widget.info.id, _onSelectionUpdate);
    }

    //Initialize drill down controller
    if (widget.drillDownController != null) {
      widget.drillDownController!.subscribe(widget.info.id, _onDrillDownUpdate);
    }

    // Initialize the reset controller
    if (widget.resetController != null) {
      widget.resetController!.stream.listen((event) {
        if (event.type == ChartResetTypes.full) {
          _axes.clear();
          _initializeAxes();
          _initializeQuadTree();
          onAxesUpdate();
        } else if (event.type == ChartResetTypes.repaint) {
          onAxesUpdate();
        }
        setState(() {});
      });
    }

    // Initialize the axes
    _initializeAxes();

    // Initialize the quadtrees
    _initializeQuadTree();
  }

  @override
  void didUpdateWidget(ScatterPlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Initialize the axes
    if (widget.info.allSeries.length == oldWidget.info.allSeries.length) {
      for (int i = 0; i < widget.info.allSeries.length; i++) {
        if (widget.info.allSeries[i].data != oldWidget.info.allSeries[i].data) {
          _initializeAxes();
          _initializeQuadTree();
          break;
        }
      }
    } else {
      _initializeAxes();
      _initializeQuadTree();
    }
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
      GlobalKey? seriesKey = _seriesKeys[series.id];

      if (seriesKey == null) {
        seriesKey = GlobalKey();
        _seriesKeys[series.id] = seriesKey;
        Marker marker = series.marker ?? Marker(color: widget.info.theme.colorCycle[colorIndex++]);

        // Determine which selection to display
        Set<Object> displayedSelection;

        // If we have active drag selections (either from this chart or from another chart),
        // use those for the display
        if (_dragSelectedPoints.isNotEmpty) {
          displayedSelection = Set<Object>.from(_dragSelectedPoints);
        } else {
          // Otherwise use the permanent selection
          displayedSelection = Set<Object>.from(selectedDataPoints);
        }

        SeriesPainter seriesPainter = SeriesPainter(
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
          selectedDataPoints: displayedSelection,
          drillDownDataPoints: drillDownDataPoints,
        );
        _seriesPainters[seriesKey] = seriesPainter;
      } else {
        // Combine selected points with drag-selected points for updates too
        Set<Object> displayedSelection = Set<Object>.from(selectedDataPoints);
        if (_isDragging && _dragSelectedPoints.isNotEmpty) {
          displayedSelection = Set<Object>.from(_dragSelectedPoints);
        }
        _seriesPainters[seriesKey]!.selectedDataPoints = displayedSelection;
        _seriesPainters[seriesKey]!.drillDownDataPoints = drillDownDataPoints;
      }
      children.add(Positioned.fill(
        child: RepaintBoundary(
          key: seriesKey,
          child: CustomPaint(
            painter: _seriesPainters[seriesKey]!,
          ),
        ),
      ));
    }

    // Add the selection box if the user is dragging
    if (dragging) {
      if (cursorAction == CursorAction.dateTimeSelect) {
        children.add(Positioned(
          left: math.min(dragStart!.dx, dragEnd!.dx),
          top: axisPainter.margin.top + axisPainter.tickPadding,
          child: Container(
            width: (dragEnd!.dx - dragStart!.dx).abs(),
            height: axisPainter.chartSize.height -
                2 * axisPainter.tickPadding -
                axisPainter.margin.top -
                axisPainter.margin.bottom,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.blue,
                width: 2,
              ),
            ),
          ),
        ));
      } else {
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
                  // See if the cursor is hovering over a point
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
    _dragSelectedPoints.clear();
    setState(() {
      _isDragging = true;
      _isDragGesture = true;
    });
  }

  /// Update the drag region size and select data points within the drag region.
  void _onDragUpdate(DragUpdateDetails details, AxisPainter axisPainter) {
    focusNode.requestFocus();

    // First update the drag end position - this ensures the selection box is drawn immediately
    dragEnd = details.localPosition;

    // For drill down or date-time select, we just update the UI
    if (cursorAction == CursorAction.drillDown || cursorAction == CursorAction.dateTimeSelect) {
      setState(() {});
      return;
    }

    // Immediately trigger a rebuild to show the updated selection box
    setState(() {});

    // Schedule the actual point selection calculations for after the frame is drawn
    // This ensures the selection box updates immediately and feels responsive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDragging) return; // Don't continue if drag has ended

      Size chartSize = axisPainter.chartSize;

      // Calculate the new selection
      Set<Object> newSelectedDataPoints = {};
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
        newSelectedDataPoints.addAll(quadTree.queryRect(
          Rect.fromPoints(projectedStart, projectedEnd),
        ));
      }

      // Update the temporary drag selection for immediate visual feedback
      _dragSelectedPoints = newSelectedDataPoints;

      // Update the selection in all series painters to ensure they show the drag selection
      _markSeriesForDragSelection();

      // Propagate the temporary selection to other charts via the selection controller
      if (widget.selectionController != null) {
        widget.selectionController!.updateTemporarySelection(widget.info.id, _dragSelectedPoints);
      }
    });
  }

  /// Update all series painters with the current drag selection
  void _markSeriesForDragSelection() {
    // Update all series painters with the current drag selection
    bool selectionChanged = false;
    for (SeriesPainter painter in _seriesPainters.values) {
      // Check if we need to update the selection
      if (!areSelectionsEqual(painter.selectedDataPoints, _dragSelectedPoints)) {
        // Update the selection
        painter.selectedDataPoints = Set<Object>.from(_dragSelectedPoints);
        selectionChanged = true;
      }
    }

    // If the selection changed, find and update the render objects
    if (selectionChanged) {
      for (GlobalKey key in _seriesKeys.values) {
        if (key.currentContext != null) {
          final renderObject = key.currentContext!.findRenderObject();
          if (renderObject is RenderRepaintBoundary) {
            renderObject.markNeedsPaint();
          }
        }
      }
    }
  }

  /// Clear the drag parameters when the user stops dragging.
  void _onDragEnd(DragEndDetails details, AxisPainter axisPainter) {
    if (cursorAction == CursorAction.drillDown) {
      for (ChartAxes axes in _axes.values) {
        // Convert the zoom area to cartesian coordinates
        double xStart = dragStart!.dx - axisPainter.margin.left - axisPainter.tickPadding;
        double yStart = dragStart!.dy - axisPainter.margin.top - axisPainter.tickPadding;
        List<double> startCoord = axes.doubleFromPixel(Offset(xStart, yStart), axisPainter.chartSize);
        double xEnd = dragEnd!.dx - axisPainter.margin.left - axisPainter.tickPadding;
        double yEnd = dragEnd!.dy - axisPainter.margin.top - axisPainter.tickPadding;
        List<double> endCoord = axes.doubleFromPixel(Offset(xEnd, yEnd), axisPainter.chartSize);
        for (int n = 0; n < axes.axes.length; n++) {
          ChartAxis axis = axes.axes.values.elementAt(n);
          double min = startCoord[n];
          double max = endCoord[n];
          if (min > max) {
            double temp = min;
            min = max;
            max = temp;
          }
          axis.updateTicksAndBounds(Bounds(min, max));
        }
      }
    }
    // Apply the drag selection and send selection update
    if (!areSelectionsEqual(selectedDataPoints, _dragSelectedPoints)) {
      selectedDataPoints = Set<Object>.from(_dragSelectedPoints);
    }

    // Now we can clean the drag (after copying the selection points)
    _cleanDrag();
    onAxesUpdate();
    developer.log("axes updated", name: "rubin_chart.ui.charts.scatter");
    setState(() {
      _isDragging = false;
      _isDragGesture = false; // Make sure to reset this flag too
    });

    // Only send selection update if we have points or if we're clearing a previous selection
    if (widget.selectionController != null &&
        (selectedDataPoints.isNotEmpty || widget.selectionController!.selectedDataPoints.isNotEmpty)) {
      widget.selectionController!.updateSelection(widget.info.id, selectedDataPoints);
    }
  }

  /// Clear the drag parameters when the user cancels dragging.
  void _onDragCancel() {
    _cleanDrag();
    setState(() {
      _isDragging = false;
      _isDragGesture = false;
    });
  }

  /// Clear the drag parameters.
  void _cleanDrag() {
    dragStart = null;
    dragEnd = null;
    _dragSelectedPoints.clear();
    setState(() {
      // We don't reset _isDragging and _isDragGesture here because
      // that's handled by the caller (_onDragEnd or _onDragCancel)
    });
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
    if (_isDragging || (_isDragGesture && !isHover)) {
      _isDragGesture = false;
      return null;
    }

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
          if ((localNearest.center - axes.linearFromPixel(pixel: Offset(x, y), chartSize: chartSize))
                  .distanceSquared <
              (nearest.center - axes.linearFromPixel(pixel: Offset(x, y), chartSize: chartSize))
                  .distanceSquared) {
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
      return null;
    }

    // Set the local selection
    Set<Object> newSelection = nearest == null ? {} : {nearest.element};
    bool selectionChanged = !areSelectionsEqual(selectedDataPoints, newSelection);
    selectedDataPoints = newSelection;

    // Update the UI with the selection
    _markSeriesNeedsUpdate();

    // Only notify the controller if selection changed and either:
    // 1. We have points OR
    // 2. We're clearing a previous non-empty selection
    if (widget.selectionController != null &&
        selectionChanged &&
        (selectedDataPoints.isNotEmpty || widget.selectionController!.selectedDataPoints.isNotEmpty)) {
      widget.selectionController!.updateSelection(widget.info.id, selectedDataPoints);
    }

    // Force a repaint to show the selection
    setState(() {});
    return null;
  }

  /// Pan the chart.
  /// We override the default behavior in order to translate the canvas
  /// so that the user can pan the chart with a large number of data points
  /// without jitter.
  @override
  void onPan(PointerScrollEvent event, AxisPainter axisPainter) {
    Size chartSize = axisPainter.chartSize;
    if (isShiftKey(scaleShiftKey)) {
      for (ChartAxes axes in allAxes.values) {
        axes.scale(
          1 - event.scrollDelta.dx / chartSize.width,
          1 + event.scrollDelta.dy / chartSize.height,
          chartSize,
        );
      }
    } else {
      for (ChartAxes axes in allAxes.values) {
        axes.translate(event.scrollDelta, chartSize);
      }
    }
    if (nPoints > kMaxScatterPoints) {
      translationOffset = translationOffset - event.scrollDelta;
      panZoomTimer?.cancel();
      panZoomTimer = Timer(const Duration(milliseconds: 100), () {
        translationOffset = Offset.zero;
        onAxesUpdate();
      });
    }
    onAxesUpdate();
    setState(() {});
  }

  Timer? panZoomTimer;

  /// We override the default behavior in order to allow the
  /// user to zoom in on the chart with a large number of data points
  /// without jitter.
  @override
  void onScale(PointerScaleEvent event, AxisPainter axisPainter) {
    for (ChartAxes axes in allAxes.values) {
      if (scaleShiftKey == null) {
        axes.scale(event.scale, event.scale, axisPainter.chartSize);
      } else if (scaleShiftKey == LogicalKeyboardKey.keyX) {
        axes.scale(event.scale, 1, axisPainter.chartSize);
      } else if (scaleShiftKey == LogicalKeyboardKey.keyY) {
        axes.scale(1, event.scale, axisPainter.chartSize);
      }
    }
    if (nPoints > kMaxScatterPoints) {
      panZoomTimer?.cancel();
      panZoomTimer = Timer(const Duration(milliseconds: 500), () {
        onAxesUpdate();
      });
    }
    setState(() {});
    onAxesUpdate();
  }

  /// Utility function to check if two selections contain the same elements
  bool areSelectionsEqual(Set<Object> a, Set<Object> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}

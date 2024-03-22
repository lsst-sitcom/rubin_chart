import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/projection.dart';
import 'package:rubin_chart/src/models/axes/ticks.dart';
import 'package:rubin_chart/src/models/marker.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/ui/axis_painter.dart';
import 'package:rubin_chart/src/ui/chart.dart';
import 'package:rubin_chart/src/ui/series_painter.dart';
import 'package:rubin_chart/src/utils/quadtree.dart';
import 'package:rubin_chart/src/utils/utils.dart';

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

  Map<Object, ChartAxes> initializeAxes();
  AxisPainter initializeAxesPainter({required Map<Object, ChartAxes> allAxes, required ChartTheme theme});
}

class ScatterPlot extends StatefulWidget {
  final ScatterPlotInfo info;
  final SelectionController? selectionController;
  final Map<AxisId, AxisController> axisControllers;
  final List<AxisId> hiddenAxes;

  const ScatterPlot({
    Key? key,
    required this.info,
    this.selectionController,
    this.axisControllers = const {},
    this.hiddenAxes = const [],
  }) : super(key: key);

  static Widget builder({
    required ChartInfo info,
    Map<AxisId, AxisController>? axisControllers,
    SelectionController? selectionController,
    List<AxisId>? hiddenAxes,
  }) {
    if (info is! ScatterPlotInfo) {
      throw ArgumentError("ScatterPlot.builder: info must be of type ScatterPlotInfo");
    }
    return ScatterPlot(
      info: info,
      selectionController: selectionController,
      axisControllers: axisControllers ?? {},
      hiddenAxes: hiddenAxes ?? [],
    );
  }

  @override
  ScatterPlotState createState() => ScatterPlotState();
}

class ScatterPlotState extends State<ScatterPlot> with ChartMixin, Scrollable2DChartMixin {
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

  /// Quadtree for the bottom left axes.
  final Map<Object, QuadTree<Object>> _quadTrees = {};

  @override
  void initState() {
    super.initState();
    // Add key detector
    focusNode.addListener(focusNodeListener);

    axisControllers.addAll(widget.axisControllers.values);
    if (widget.selectionController != null) {
      widget.selectionController!.subscribe((Set<Object> dataPoints) {
        selectedDataPoints = dataPoints;
        setState(() {});
      });
    }

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

    // Initialize the quadtrees
    List<Object> axesIndices = _axes.keys.toList();
    for (Object axesIndex in axesIndices) {
      ChartAxis axis0 = _axes[axesIndex]!.axes.values.first;
      ChartAxis axis1 = _axes[axesIndex]!.axes.values.last;

      _quadTrees[axesIndex] = QuadTree(
        maxDepth: widget.info.theme.quadTreeDepth,
        capacity: widget.info.theme.quadTreeCapacity,
        contents: [],
        children: [],
        left: axis0.bounds.min.toDouble(),
        top: axis1.bounds.min.toDouble(),
        width: (axis0.bounds.max - axis0.bounds.min).toDouble(),
        height: (axis1.bounds.max - axis1.bounds.min).toDouble(),
      );
    }

    // Populate the quadtrees
    for (Series series in widget.info.allSeries) {
      ChartAxes axes = _axes[series.axesId]!;
      AxisId axisId0 = axes.axes.keys.first;
      AxisId axisId1 = axes.axes.keys.last;

      ChartAxis axis0 = axes[axisId0];
      ChartAxis axis1 = axes[axisId1];
      dynamic columnX = series.data.data[series.data.plotColumns[axisId0]]!.values.toList();
      dynamic columnY = series.data.data[series.data.plotColumns[axisId1]]!.values.toList();

      for (int i = 0; i < series.data.length; i++) {
        dynamic seriesX = columnX[i];
        dynamic seriesY = columnY[i];
        double x = axis0.toDouble(seriesX);
        double y = axis1.toDouble(seriesY);

        _quadTrees[series.axesId]!.insert(
          series.data.data[series.data.plotColumns.values.first]!.keys.toList()[i],
          Offset(x, y),
        );
      }
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
                selectedDataPoints: selectedDataPoints),
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (TapUpDetails details) {
                _onTapUp(details, axisPainter);
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

  void _onDragStart(DragStartDetails details, AxisPainter axisPainter) {
    focusNode.requestFocus();
    if (axisPainter.projections == null) {
      return;
    }
    dragStart = details.localPosition;
    dragEnd = details.localPosition;
    selectedDataPoints.clear();
    setState(() {});
  }

  void _onDragUpdate(DragUpdateDetails details, AxisPainter axisPainter) {
    focusNode.requestFocus();
    if (axisPainter.projections == null) {
      return;
    }
    dragEnd = details.localPosition;

    selectedDataPoints = {};
    for (MapEntry<Object, QuadTree<Object>> entry in _quadTrees.entries) {
      Object axesId = entry.key;
      QuadTree<Object> quadTree = entry.value;
      // Select points that fit inside the selection box
      Projection projection = axisPainter.projections![axesId]!;
      Offset projectedStart = Offset(
        projection.xTransform.inverse(dragStart!.dx - axisPainter.margin.left - axisPainter.tickPadding),
        projection.yTransform.inverse(dragStart!.dy - axisPainter.margin.top - axisPainter.tickPadding),
      );
      Offset projectedEnd = Offset(
        projection.xTransform.inverse(dragEnd!.dx - axisPainter.margin.left - axisPainter.tickPadding),
        projection.yTransform.inverse(dragEnd!.dy - axisPainter.margin.top - axisPainter.tickPadding),
      );

      selectedDataPoints.addAll(quadTree.queryRect(
        Rect.fromPoints(projectedStart, projectedEnd),
      ));
    }

    if (widget.selectionController != null) {
      widget.selectionController!.updateSelection(null, selectedDataPoints);
    }

    setState(() {});
  }

  void _onDragEnd(DragEndDetails details, AxisPainter axisPainter) => _cleanDrag();

  void _onDragCancel() => _cleanDrag();

  void _cleanDrag() {
    dragStart = null;
    dragEnd = null;
    setState(() {});
  }

  void _onTapUp(TapUpDetails details, AxisPainter axisPainter) {
    focusNode.requestFocus();
    if (axisPainter.projections == null) {
      return;
    }

    QuadTreeElement? nearest;
    for (MapEntry<Object, QuadTree<Object>> entry in _quadTrees.entries) {
      Object axesId = entry.key;
      QuadTree<Object> quadTree = entry.value;
      // Select nearest point in the quadtree.
      Projection projection = axisPainter.projections![axesId]!;
      double x = projection.xTransform
          .inverse(details.localPosition.dx - axisPainter.margin.left - axisPainter.tickPadding);
      double y = projection.yTransform
          .inverse(details.localPosition.dy - axisPainter.margin.top - axisPainter.tickPadding);

      QuadTreeElement? localNearest = quadTree.queryPoint(Offset(x, y),
          distance: Offset(10 / projection.xTransform.scale, 10 / projection.yTransform.scale));
      if (localNearest != null) {
        Offset diff = (localNearest.center - Offset(x, y));
        double dx = projection.xTransform.scale * diff.dx;
        double dy = projection.yTransform.scale * diff.dy;
        // Check that the nearest point is inside the selection radius.
        if (dx * dx + dy * dy > 100) {
          continue;
        }
        if (nearest != null) {
          if ((localNearest.center - Offset(x, y)).distanceSquared <
              (nearest.center - Offset(x, y)).distanceSquared) {
            nearest = localNearest;
          }
        } else {
          nearest = localNearest;
        }
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
    setState(() {});
  }
}

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/projection.dart';
import 'package:rubin_chart/src/models/marker.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/ui/axis_painter.dart';
import 'package:rubin_chart/src/ui/chart.dart';
import 'package:rubin_chart/src/ui/series_painter.dart';
import 'package:rubin_chart/src/utils/quadtree.dart';

class ScatterPlotInfo extends ChartInfo {
  ScatterPlotInfo({
    required super.allSeries,
    super.title,
    super.theme,
    super.legend,
    super.axisInfo,
    super.colorCycle,
    super.projectionInitializer = CartesianProjection.fromAxes,
    super.interiorAxisLabelLocation,
  }) : super(builder: ScatterPlot.builder);
}

class ScatterPlot extends StatefulWidget {
  final ScatterPlotInfo info;
  final SelectionController? selectionController;
  final List<AxisController>? axesControllers;

  const ScatterPlot({
    Key? key,
    required this.info,
    this.selectionController,
    this.axesControllers,
  }) : super(key: key);

  static Widget builder({
    required ChartInfo info,
    List<AxisController>? axesControllers,
    SelectionController? selectionController,
  }) {
    if (info is! ScatterPlotInfo) {
      throw ArgumentError("ScatterPlot.builder: info must be of type ScatterPlotInfo");
    }
    return ScatterPlot(
        info: info, selectionController: selectionController, axesControllers: axesControllers);
  }

  @override
  ScatterPlotState createState() => ScatterPlotState();
}

class ScatterPlotState extends State<ScatterPlot> with ChartMixin {
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

  /// The selected (and highlighted) data points.
  List<Object> selectedDataPoints = [];

  bool get dragging => dragStart != null;
  Offset? dragStart;
  Offset? dragEnd;

  @override
  void initState() {
    super.initState();
    // Initialize the axes
    _axes.addAll(initializeSimpleAxes(
      seriesList: widget.info.allSeries,
      axisInfo: widget.info.axisInfo,
      theme: widget.info.theme,
      projectionInitializer: widget.info.projectionInitializer,
    ));

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
        width: axis0.bounds.range.toDouble(),
        height: axis1.bounds.range.toDouble(),
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

    AxisPainter axisPainter = AxisPainter(
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

    return Listener(
        onPointerSignal: (PointerSignalEvent event) {
          if (event is PointerScrollEvent) {
            _onPan(event, axisPainter);
          } else if (event is PointerScaleEvent) {
            _onScale(event, axisPainter);
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
        ));
  }

  void _onDragStart(DragStartDetails details, AxisPainter axisPainter) {
    if (axisPainter.projections == null) {
      return;
    }
    dragStart = details.localPosition;
    dragEnd = details.localPosition;
    selectedDataPoints.clear();
    setState(() {});
  }

  void _onDragUpdate(DragUpdateDetails details, AxisPainter axisPainter) {
    if (axisPainter.projections == null) {
      return;
    }
    dragEnd = details.localPosition;

    selectedDataPoints = [];
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

      QuadTreeElement? localNearest = quadTree.queryPoint(Offset(x, y));
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
      selectedDataPoints = [];
    } else {
      selectedDataPoints = [nearest.element];
    }
    setState(() {});
  }

  void _onScale(PointerScaleEvent event, AxisPainter axisPainter) {
    if (axisPainter.projections == null) {
      return;
    }

    for (ChartAxes axes in _axes.values) {
      for (AxisId axisId in axes.axes.keys) {
        ChartAxis axis = axes[axisId];
        axis.scale(event.scale);
      }
    }

    setState(() {});
  }

  void _onPan(PointerScrollEvent event, AxisPainter axisPainter) {
    if (axisPainter.projections == null) {
      return;
    }

    for (MapEntry<Object, ChartAxes> entry in _axes.entries) {
      Object axesId = entry.key;
      ChartAxes axes = entry.value;
      double dx = event.scrollDelta.dx;
      double dy = event.scrollDelta.dy;

      Projection projection = axisPainter.projections![axesId]!;
      dx /= projection.xTransform.scale;
      dy /= projection.yTransform.scale;

      for (AxisId axisId in axes.axes.keys) {
        ChartAxis axis = axes[axisId];

        if (axis.info.axisId.location == AxisLocation.bottom ||
            axis.info.axisId.location == AxisLocation.top) {
          axis.translate(dx);
        } else {
          axis.translate(dy);
        }
      }
    }

    setState(() {});
  }
}

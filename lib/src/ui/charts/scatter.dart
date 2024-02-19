import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/projection.dart';
import 'package:rubin_chart/src/models/marker.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/ui/axis_painter.dart';
import 'package:rubin_chart/src/ui/chart.dart';
import 'package:rubin_chart/src/ui/series_painter.dart';
import 'package:rubin_chart/src/utils/quadtree.dart';

class ScatterPlot<C, I, A> extends StatefulWidget {
  final ChartTheme theme;
  final List<Series<C, I, A>> seriesList;
  final ProjectionInitializer projectionInitializer;
  final Map<AxisId<A>, ChartAxisInfo> axisInfo;
  final SelectionController? selectionController;

  const ScatterPlot({
    Key? key,
    required this.seriesList,
    this.theme = const ChartTheme(),
    this.projectionInitializer = CartesianProjection.fromAxes,
    required this.axisInfo,
    this.selectionController,
  }) : super(key: key);

  @override
  ScatterPlotState createState() => ScatterPlotState();
}

class ScatterPlotState<C, I, A> extends State<ScatterPlot<C, I, A>> with ChartMixin {
  /// Make the widget's series accessible to the state.
  @override
  SeriesList get seriesList => SeriesList(
        widget.seriesList,
        widget.theme.colorCycle,
      );

  /// The axes of the chart.
  @override
  Map<A, ChartAxes> get axes => _axes;

  /// The axes of the chart.
  final Map<A, ChartAxes> _axes = {};

  /// Quadtree for the bottom left axes.
  final Map<A, QuadTree<I>> _quadTrees = {};

  /// The selected (and highlighted) data points.
  List<I> selectedDataPoints = [];

  bool get dragging => dragStart != null;
  Offset? dragStart;
  Offset? dragEnd;

  @override
  void initState() {
    super.initState();
    // Initialize the axes
    _axes.addAll(initializeSimpleAxes(
      seriesList: widget.seriesList,
      axisInfo: widget.axisInfo,
      theme: widget.theme,
      projectionInitializer: widget.projectionInitializer,
    ));

    // Initialize the quadtrees
    List<A> axesIndices = _axes.keys.toList();
    for (A axesIndex in axesIndices) {
      ChartAxis axis0 = _axes[axesIndex]!.axes.values.first;
      ChartAxis axis1 = _axes[axesIndex]!.axes.values.last;

      _quadTrees[axesIndex] = QuadTree(
        maxDepth: widget.theme.quadTreeDepth,
        capacity: widget.theme.quadTreeCapacity,
        contents: [],
        children: [],
        left: axis0.bounds.min.toDouble(),
        top: axis1.bounds.min.toDouble(),
        width: axis0.bounds.range.toDouble(),
        height: axis1.bounds.range.toDouble(),
      );
    }

    // Populate the quatrees
    for (Series series in widget.seriesList) {
      ChartAxes axes = _axes[series.axesId]!;
      AxisId axisId0 = axes.axes.keys.first;
      AxisId axisId1 = axes.axes.keys.last;

      ChartAxis axis0 = axes[axisId0];
      ChartAxis axis1 = axes[axisId1];

      for (int i = 0; i < series.data.length; i++) {
        dynamic seriesX = series.data.data[series.data.plotColumns[axisId0]]!.values.toList()[i];
        dynamic seriesY = series.data.data[series.data.plotColumns[axisId1]]!.values.toList()[i];
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
      theme: widget.theme,
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
      if (colorIndex >= widget.theme.colorCycle.length) {
        colorIndex = 0;
      }
      Series series = seriesList[i];
      Marker marker = series.marker ?? Marker(color: widget.theme.colorCycle[colorIndex++]);
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
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.red,
                width: 2,
              ),
              //borderRadius: BorderRadius.circular(10),
            ),
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

    // Select points that fit inside the selection box
    Projection projection = axisPainter.projections!.values.first;
    Offset projectedStart = Offset(
      projection.xTransform.inverse(dragStart!.dx - axisPainter.margin.left - axisPainter.tickPadding),
      projection.yTransform.inverse(dragStart!.dy - axisPainter.margin.top - axisPainter.tickPadding),
    );
    Offset projectedEnd = Offset(
      projection.xTransform.inverse(dragEnd!.dx - axisPainter.margin.left - axisPainter.tickPadding),
      projection.yTransform.inverse(dragEnd!.dy - axisPainter.margin.top - axisPainter.tickPadding),
    );

    List<dynamic> newSelectedDataPoints = [];
    for (QuadTree quadTree in _quadTrees.values) {
      newSelectedDataPoints.addAll(quadTree.queryRect(
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

    Projection projection = axisPainter.projections!.values.first;
    double x = projection.xTransform
        .inverse(details.localPosition.dx - axisPainter.margin.left - axisPainter.tickPadding);
    double y = projection.yTransform
        .inverse(details.localPosition.dy - axisPainter.margin.top - axisPainter.tickPadding);

    QuadTreeElement? nearest;
    for (QuadTree quadTree in _quadTrees.values) {
      QuadTreeElement? localNearest = quadTree.queryPoint(Offset(x, y));
      if (localNearest != null) {
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
      Offset diff = (nearest.center - Offset(x, y));
      double dx = projection.xTransform.scale * diff.dx;
      double dy = projection.yTransform.scale * diff.dy;
      if (dx * dx + dy * dy > 100) {
        selectedDataPoints = [];
      } else {
        selectedDataPoints = [nearest.element];
      }
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

    double dx = event.scrollDelta.dx;
    double dy = event.scrollDelta.dy;

    Projection projection = axisPainter.projections!.values.first;
    dx /= projection.xTransform.scale;
    dy /= projection.yTransform.scale;

    for (ChartAxes axes in _axes.values) {
      for (AxisId axisId in axes.axes.keys) {
        ChartAxis axis = axes[axisId];
        if (axis.info.location == AxisLocation.bottom || axis.info.location == AxisLocation.top) {
          axis.translate(dx);
        } else {
          axis.translate(dy);
        }
      }
    }

    setState(() {});
  }
}

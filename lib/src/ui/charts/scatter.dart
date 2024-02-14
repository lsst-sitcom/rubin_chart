import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/projection.dart';
import 'package:rubin_chart/src/models/legend.dart';
import 'package:rubin_chart/src/models/marker.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/ui/axis_painter.dart';
import 'package:rubin_chart/src/ui/chart.dart';
import 'package:rubin_chart/src/ui/series_painter.dart';
import 'package:rubin_chart/src/utils/quadtree.dart';

class ScatterPlot extends StatefulWidget {
  final ChartTheme theme;
  final List<Series> seriesList;
  final Legend legend;
  final ProjectionInitializer projectionInitializer;
  final List<ChartAxis>? axes;

  const ScatterPlot({
    Key? key,
    required this.seriesList,
    this.theme = const ChartTheme(),
    this.legend = const Legend(),
    this.projectionInitializer = CartesianProjection.fromAxes,
    this.axes,
  }) : super(key: key);

  @override
  ScatterPlotState createState() => ScatterPlotState();
}

class ScatterPlotState extends State<ScatterPlot> with ChartMixin {
  /// Make the widget's series accessible to the state.
  @override
  List<Series> get seriesList => widget.seriesList;

  /// Make the widget's theme accessible to the state.
  @override
  Legend get legend => widget.legend;

  /// The axes of the chart.
  @override
  List<ChartAxis> get axes => _axes;

  /// The axes of the chart.
  final List<ChartAxis> _axes = [];

  /// Quadtree for the bottom left axes.
  late QuadTree _quadTreeBL;

  /// Quadtree for the top right axes.
  late QuadTree _quadTreeTR;

  List<dynamic> selectedDataPoints = [];

  @override
  void initState() {
    super.initState();
    if (widget.axes != null) {
      _axes.addAll(widget.axes!);
    } else {
      _axes.addAll(initializeAxes2D(seriesList: seriesList, theme: widget.theme));
    }

    _quadTreeBL = QuadTree(
      maxDepth: widget.theme.quadTreeDepth,
      capacity: widget.theme.quadTreeCapacity,
      contents: [],
      children: [],
      left: axes[0].bounds.min.toDouble(),
      top: axes[1].bounds.min.toDouble(),
      width: axes[0].bounds.range.toDouble(),
      height: axes[1].bounds.range.toDouble(),
    );

    _quadTreeTR = QuadTree(
      maxDepth: widget.theme.quadTreeDepth,
      capacity: widget.theme.quadTreeCapacity,
      contents: [],
      children: [],
      left: 0,
      top: 0,
      width: 1,
      height: 1,
    );

    for (Series series in seriesList) {
      late final ChartAxis xAxis;
      late final ChartAxis yAxis;
      if (series.axesIndex == 0) {
        xAxis = _axes[0];
        yAxis = _axes[1];
      } else {
        xAxis = _axes[2];
        yAxis = _axes[3];
      }

      for (int i = 0; i < series.data.length; i++) {
        dynamic seriesX = series.data.data[series.data.plotColumns[0]]!.values.toList()[i];
        dynamic seriesY = series.data.data[series.data.plotColumns[1]]!.values.toList()[i];
        double x = xAxis.toDouble(seriesX);
        double y = yAxis.toDouble(seriesY);

        if (series.axesIndex == 0) {
          _quadTreeBL.insert(
            series.data.data[series.data.plotColumns[0]]!.keys.toList()[i],
            Offset(x, y),
          );
        } else {
          _quadTreeTR.insert(
            series.data.data[series.data.plotColumns[0]]!.keys.toList()[i],
            Offset(x, y),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];

    AxisPainter axisPainter = AxisPainter(
      axes: axes,
      ticks: axes.map((e) => e.ticks).toList(),
      projectionInitializer: widget.projectionInitializer,
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
                axes: axes,
                marker: marker,
                errorBars: series.errorBars,
                projectionInitializer: widget.projectionInitializer,
                data: series.data,
                tickLabelMargin: EdgeInsets.only(
                  left: axisPainter.leftMargin + axisPainter.tickPadding,
                  right: axisPainter.rightMargin + axisPainter.tickPadding,
                  top: axisPainter.topMargin + axisPainter.tickPadding,
                  bottom: axisPainter.bottomMargin + axisPainter.tickPadding,
                ),
                selectedDataPoints: selectedDataPoints),
          ),
        ),
      );
    }

    return Listener(
        onPointerSignal: (PointerSignalEvent event) {
          if (event is PointerScrollEvent) {
            _onPan(event, axisPainter);
          } else if (event is PointerScaleEvent) {
            _onScale(event, axisPainter);
          } else {
            print("Event is ${event.runtimeType}");
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (TapUpDetails details) {
            _onTapUp(details, axisPainter);
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

  void _onTapUp(TapUpDetails details, AxisPainter axisPainter) {
    if (axisPainter.projection == null) {
      return;
    }

    Projection projection = axisPainter.projection!;
    double x = projection.xTransform
        .inverse(details.localPosition.dx - axisPainter.leftMargin - axisPainter.tickPadding);
    double y = projection.yTransform
        .inverse(details.localPosition.dy - axisPainter.topMargin - axisPainter.tickPadding);

    QuadTreeElement? nearest = _quadTreeBL.queryPoint(Offset(x, y));

    if (nearest == null) {
      selectedDataPoints = [];
    } else {
      selectedDataPoints = [nearest.element];
    }
    setState(() {});
  }

  void _onScale(PointerScaleEvent event, AxisPainter axisPainter) {
    if (axisPainter.projection == null) {
      return;
    }

    for (int i = 0; i < axes.length; i++) {
      axes[i] = axes[i].scaled(event.scale);
    }
    setState(() {});
  }

  void _onPan(PointerScrollEvent event, AxisPainter axisPainter) {
    if (axisPainter.projection == null) {
      return;
    }

    double dx = event.scrollDelta.dx;
    double dy = event.scrollDelta.dy;

    Projection projection = axisPainter.projection!;
    dx /= projection.xTransform.scale;
    dy /= projection.yTransform.scale;

    for (int i = 0; i < axes.length; i++) {
      if (i % 2 == 0) {
        axes[i] = axes[i].translated(dx);
      } else {
        axes[i] = axes[i].translated(dy);
      }
    }
    setState(() {});
  }
}

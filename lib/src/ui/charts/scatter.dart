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

  @override
  void initState() {
    super.initState();
    if (widget.axes != null) {
      _axes.addAll(widget.axes!);
    } else {
      _axes.addAll(initializeAxes2D(seriesList: seriesList, theme: widget.theme));
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
            ),
          ),
        ),
      );
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: (PointerSignalEvent event) {
        if (event is PointerScrollEvent) {
          _onPan(event, axisPainter);
        }

        if (event is PointerScaleEvent) {
          _onScale(event, axisPainter);
        }
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
    );
  }

  void _onScale(PointerScaleEvent event, AxisPainter axisPainter) {
    if (axisPainter.projection == null) {
      return;
    }

    //print("scaling by ${event.scale}");

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

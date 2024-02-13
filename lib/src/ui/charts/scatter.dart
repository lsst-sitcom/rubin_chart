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

    // Draw the axes
    children.add(
      Positioned.fill(
        child: CustomPaint(
          painter: AxisPainter(
            axes: axes,
            ticks: axes.map((e) => e.ticks).toList(),
            projectionInitializer: widget.projectionInitializer,
            theme: widget.theme,
          ),
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
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.red,
          width: 2,
        ),
        //borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(children: children),
    );
  }
}

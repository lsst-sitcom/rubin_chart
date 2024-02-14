import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/projection.dart';
import 'package:rubin_chart/src/models/marker.dart';
import 'package:rubin_chart/src/models/series.dart';

/// Paint a 2D [Series] in a plot.
class SeriesPainter extends CustomPainter {
  /// The axes of the plot, used to project the markers onto the plot.
  final List<ChartAxis> axes;

  /// The marker style used for the series.
  final Marker marker;

  /// The error bar style used for the series.
  final ErrorBars? errorBars;

  /// The projection used for the series.
  ProjectionInitializer projectionInitializer;

  /// The x coordinates of the data points.
  final SeriesData data;

  /// Offset from the lower left to make room for labels.
  final EdgeInsets tickLabelMargin;

  final List<dynamic> selectedDataPoints;

  SeriesPainter({
    required this.axes,
    required this.marker,
    required this.errorBars,
    required this.projectionInitializer,
    required this.data,
    this.tickLabelMargin = EdgeInsets.zero,
    this.selectedDataPoints = const [],
  });

  /// Paint the series on the [Canvas].
  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the projection used for all points in the series
    Size plotSize = Size(size.width - tickLabelMargin.left - tickLabelMargin.right,
        size.height - tickLabelMargin.top - tickLabelMargin.bottom);
    Rect plotWindow = Offset(tickLabelMargin.left, tickLabelMargin.top) & plotSize;
    Offset offset = Offset(tickLabelMargin.left, tickLabelMargin.top);
    Projection projection = projectionInitializer(
      axes: axes,
      plotSize: plotSize,
    );

    // Since all of the objects in the series use the same marker style,
    // we can calculate the [Paint] objects once and reuse them.
    Color? fillColor = marker.color;
    Color? edgeColor = marker.edgeColor;
    Paint? paintFill;
    Paint? paintEdge;
    if (fillColor != null) {
      paintFill = Paint()..color = fillColor;
    }
    if (edgeColor != null) {
      paintEdge = Paint()
        ..color = edgeColor
        ..strokeWidth = marker.size / 10
        ..style = PaintingStyle.stroke;
    }

    //print("${data.length} total sources");
    //print("Window size: $plotWindow");

    //int nDisplayed = 0;

    Marker selectionMarker = marker.copyWith(size: marker.size * 2, edgeColor: Colors.black);

    for (int i = 0; i < data.length; i++) {
      Offset point = projection.project(data: data.getRow(i), axes: axes);
      if (plotWindow.contains(point)) {
        marker.paint(canvas, paintFill, paintEdge, point + offset);
        //nDisplayed++;
        // TODO: draw error bars
      }
    }

    for (dynamic dataId in selectedDataPoints) {
      if (data.data.values.first.containsKey(dataId)) {
        int index = data.data.values.first.keys.toList().indexOf(dataId);
        Offset point = projection.project(data: data.getRow(index), axes: axes);
        if (plotWindow.contains(point)) {
          selectionMarker.paint(canvas, Paint()..color = Colors.black, paintEdge, point + offset);
          //nDisplayed++;
        }
      }
    }

    //print("Plotted $nDisplayed");
  }

  @override
  bool shouldRepaint(SeriesPainter oldDelegate) {
    /// TODO: add checks for marker, errorbar, axes changes
    return oldDelegate.data != data ||
        oldDelegate.tickLabelMargin != tickLabelMargin ||
        oldDelegate.selectedDataPoints != selectedDataPoints;
  }
}

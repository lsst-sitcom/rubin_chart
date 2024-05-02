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

import 'package:flutter/material.dart';
import 'package:rubin_chart/src/models/axes/axes.dart';
import 'package:rubin_chart/src/models/marker.dart';
import 'package:rubin_chart/src/models/series.dart';

/// Paint a 2D [Series] in a plot.
class SeriesPainter extends CustomPainter {
  /// The axes of the plot, used to project the markers onto the plot.
  final ChartAxes axes;

  /// The marker style used for the series.
  final Marker marker;

  /// The error bar style used for the series.
  final ErrorBars? errorBars;

  /// The x coordinates of the data points.
  final SeriesData data;

  /// Offset from the lower left to make room for labels.
  final EdgeInsets tickLabelMargin;

  final Set<Object> selectedDataPoints;

  final Set<Object> drillDownDataPoints;

  SeriesPainter({
    required this.axes,
    required this.marker,
    required this.errorBars,
    required this.data,
    this.tickLabelMargin = EdgeInsets.zero,
    this.selectedDataPoints = const {},
    this.drillDownDataPoints = const {},
  });

  /// Paint the series on the [Canvas].
  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the projection used for all points in the series
    Size plotSize = Size(size.width - tickLabelMargin.left - tickLabelMargin.right,
        size.height - tickLabelMargin.top - tickLabelMargin.bottom);
    Rect plotWindow = Offset(tickLabelMargin.left, tickLabelMargin.top) & plotSize;
    Offset offset = Offset(tickLabelMargin.left, tickLabelMargin.top);

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

    Marker selectionMarker = marker.copyWith(size: marker.size * 1.2, edgeColor: Colors.black);

    List<Object> dataIds = data.data.values.first.keys.toList();
    for (int i = 0; i < data.length; i++) {
      Object dataId = dataIds[i];
      if (drillDownDataPoints.isNotEmpty && !drillDownDataPoints.contains(dataId)) {
        continue;
      }
      Offset point = axes.project(data: data.getRow(dataId), chartSize: plotSize) + offset;
      if (plotWindow.contains(point)) {
        marker.paint(canvas, paintFill, paintEdge, point);
        //nDisplayed++;
        // TODO: draw error bars
      }
    }

    paintEdge = Paint()
      ..color = Colors.black
      ..strokeWidth = selectionMarker.size / 3
      ..style = PaintingStyle.stroke;
    for (dynamic dataId in selectedDataPoints) {
      if (data.data.values.first.containsKey(dataId)) {
        Offset point = axes.project(data: data.getRow(dataId), chartSize: plotSize) + offset;
        if (plotWindow.contains(point)) {
          selectionMarker.paint(canvas, paintFill, paintEdge, point);
          //nDisplayed++;
        }
      }
    }

    //print("Plotted $nDisplayed");
  }

  @override
  bool shouldRepaint(SeriesPainter oldDelegate) {
    return false;

    /// TODO: add checks for marker, errorbar, axes changes
    return oldDelegate.data != data ||
        oldDelegate.tickLabelMargin != tickLabelMargin ||
        oldDelegate.selectedDataPoints != selectedDataPoints;
  }
}

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
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:rubin_chart/src/models/axes/axes.dart';
import 'package:rubin_chart/src/models/marker.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/ui/charts/scatter.dart';

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

  Set<Object> selectedDataPoints;

  Set<Object> drillDownDataPoints;

  Rect _plotWindow = Rect.zero;
  Size _size = Size.zero;

  ui.Picture? cachedPicture;

  Offset translationOffset;
  int _dataLength = 0;

  SeriesPainter({
    required this.axes,
    required this.marker,
    required this.errorBars,
    required this.data,
    this.tickLabelMargin = EdgeInsets.zero,
    this.selectedDataPoints = const {},
    this.drillDownDataPoints = const {},
    this.translationOffset = Offset.zero,
  }) {
    //print("Creating SeriesPainter");
  }

  /// Paint the series on the [Canvas].
  @override
  void paint(Canvas canvas, Size size) {
    //developer.log("painting SERIES!", name: "rubin_chart.ui.series_painter");
    // Calculate the projection used for all points in the series
    Size plotSize = Size(size.width - tickLabelMargin.left - tickLabelMargin.right,
        size.height - tickLabelMargin.top - tickLabelMargin.bottom);
    Rect plotWindow = Offset.zero & plotSize;
    Offset offset = Offset(tickLabelMargin.left, tickLabelMargin.top);

    canvas.save();
    canvas.clipRect(offset & plotSize);

    // Shift the canvas if there is a translation
    canvas.translate(translationOffset.dx + offset.dx, translationOffset.dy + offset.dy);

    // Scale the canvas if the plot window has changed
    if (_plotWindow != plotWindow && _size != Size.zero && _dataLength >= kMaxScatterPoints) {
      double sx = plotWindow.width / _plotWindow.width;
      double sy = plotWindow.height / _plotWindow.height;
      //double sx = size.width / _size.width;
      //double sy = size.height / _size.height;
      canvas.scale(sx, sy);
      double tx = (sx - 1) * tickLabelMargin.left;
      double ty = (sy - 1) * tickLabelMargin.top;
      canvas.translate(tx, ty);
    }

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

    if (cachedPicture == null || data.data.values.length < kMaxScatterPoints) {
      _plotWindow = plotWindow;
      _size = size;
      _dataLength = data.data.values.length;
      // If the plot window has changed, we need to redraw the series
      // Here we initialize the recorder to cache the data points as an image.
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas cachedCanvas = _dataLength < kMaxScatterPoints ? canvas : Canvas(recorder);

      List<Object> dataIds = data.data.values.first.keys.toList();
      //developer.log("drawing ${dataIds.length} data points");
      for (int i = 0; i < data.length; i++) {
        Object dataId = dataIds[i];
        if (drillDownDataPoints.isNotEmpty && !drillDownDataPoints.contains(dataId)) {
          continue;
        }
        Offset point = axes.project(data: data.getRow(dataId, axes.axes.keys), chartSize: plotSize);
        if (plotWindow.contains(point)) {
          marker.paint(cachedCanvas, paintFill, paintEdge, point);
          // TODO: draw error bars
        }
      }

      // Finish the recording and save the image
      if (_dataLength > kMaxScatterPoints) {
        cachedPicture = recorder.endRecording();
        canvas.drawPicture(cachedPicture!);
      }
    } else if (cachedPicture != null) {
      canvas.drawPicture(cachedPicture!);
    }

    Marker selectionMarker = marker.copyWith(size: marker.size * 1.2, edgeColor: Colors.black);
    paintEdge = Paint()
      ..color = Colors.black
      ..strokeWidth = selectionMarker.size / 3
      ..style = PaintingStyle.stroke;
    for (dynamic dataId in selectedDataPoints) {
      if (data.data.values.first.containsKey(dataId)) {
        Offset point = axes.project(data: data.getRow(dataId, axes.axes.keys), chartSize: plotSize);
        point -= translationOffset;
        if (plotWindow.contains(point)) {
          selectionMarker.paint(canvas, paintFill, paintEdge, point);
          //nDisplayed++;
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SeriesPainter oldDelegate) {
    return true;

    /// TODO: add checks for marker, errorbar, axes changes
    return oldDelegate.data != data ||
        oldDelegate.tickLabelMargin != tickLabelMargin ||
        oldDelegate.selectedDataPoints != selectedDataPoints;
  }
}

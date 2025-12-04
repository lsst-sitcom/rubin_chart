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
import 'dart:developer' as developer;
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

  /// Cache for selection picture
  ui.Picture? cachedSelectionPicture;
  Set<Object> _lastSelectedDataPoints = {};

  Offset translationOffset;

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

  int _paintCallCount = 0;
  final List<Duration> _paintDurations = [];

  /// Paint the series on the [Canvas].
  @override
  void paint(Canvas canvas, Size size) {
    final Stopwatch stopwatch = Stopwatch()..start();

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
    if (_plotWindow != plotWindow && _size != Size.zero && data.length >= kMaxScatterPoints) {
      final scaleStopwatch = Stopwatch()..start();
      double sx = plotWindow.width / _plotWindow.width;
      double sy = plotWindow.height / _plotWindow.height;
      canvas.scale(sx, sy);
      double tx = (sx - 1) * tickLabelMargin.left;
      double ty = (sy - 1) * tickLabelMargin.top;
      canvas.translate(tx, ty);
      scaleStopwatch.stop();
      developer.log("Scale operation: ${scaleStopwatch.elapsedMilliseconds}ms", name: "rubin_chart.perf");
    }

    // Since all of the objects in the series use the same marker style,
    // we can calculate the [Paint] objects once and reuse them.
    Color? fillColor = marker.color;
    Color? edgeColor = marker.edgeColor;
    Paint? paintFill;
    Paint? paintEdge;
    Paint? paintFiltered;
    if (fillColor != null) {
      paintFill = Paint()..color = fillColor;
      paintFiltered = Paint()..color = const ui.Color.fromARGB(100, 181, 181, 181);
    }
    if (edgeColor != null) {
      paintEdge = Paint()
        ..color = edgeColor
        ..strokeWidth = marker.size / 10
        ..style = PaintingStyle.stroke;
    }

    // Series rendering
    if (cachedPicture == null || data.length < kMaxScatterPoints) {
      final seriesStopwatch = Stopwatch()..start();
      _plotWindow = plotWindow;
      _size = size;

      // For large datasets, always use picture recording for caching
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas paintCanvas = data.length < kMaxScatterPoints ? canvas : Canvas(recorder);

      List<Object> dataIds = data.data.values.first.keys.toList();

      for (int i = 0; i < data.length; i++) {
        Object dataId = dataIds[i];
        Offset point = axes.project(data: data.getRow(dataId, axes.axes.keys), chartSize: plotSize);
        if (plotWindow.contains(point)) {
          if (drillDownDataPoints.isNotEmpty && !drillDownDataPoints.contains(dataId)) {
            marker.paint(paintCanvas, paintFiltered, null, point);
          } else {
            marker.paint(paintCanvas, paintFill, paintEdge, point);
          }
        }
      }

      // Record and cache for large datasets
      if (data.length >= kMaxScatterPoints) {
        developer.log("Caching series picture with ${data.length} points",
            name: "rubin_chart.ui.series_painter");
        cachedPicture = recorder.endRecording();
        canvas.drawPicture(cachedPicture!);
      }

      seriesStopwatch.stop();
      developer.log("Series rendering: ${seriesStopwatch.elapsedMilliseconds}ms for ${data.length} points",
          name: "rubin_chart.perf");
    } else if (cachedPicture != null) {
      canvas.drawPicture(cachedPicture!);
    }

    // Paint selections - use cached picture if available and selections haven't changed
    if (selectedDataPoints != _lastSelectedDataPoints || cachedSelectionPicture == null) {
      final selectionStopwatch = Stopwatch()..start();
      _lastSelectedDataPoints = Set<Object>.from(selectedDataPoints);

      Marker selectionMarker = marker.copyWith(size: marker.size * 1.2, edgeColor: Colors.black);
      paintEdge = Paint()
        ..color = Colors.black
        ..strokeWidth = selectionMarker.size / 3
        ..style = PaintingStyle.stroke;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas selectionCanvas = Canvas(recorder);

      if (selectedDataPoints.isNotEmpty) {
        final firstDataMap = data.data.values.first;
        for (Object dataId in selectedDataPoints) {
          if (firstDataMap.containsKey(dataId)) {
            Offset point = axes.project(data: data.getRow(dataId, axes.axes.keys), chartSize: plotSize);
            if (plotWindow.contains(point)) {
              selectionMarker.paint(selectionCanvas, paintFill, paintEdge, point);
            }
          }
        }
      }

      cachedSelectionPicture = recorder.endRecording();
      selectionStopwatch.stop();
      developer.log(
          "Selection rendering: ${selectionStopwatch.elapsedMilliseconds}ms for ${selectedDataPoints.length} points",
          name: "rubin_chart.perf");
    }

    if (cachedSelectionPicture != null) {
      canvas.drawPicture(cachedSelectionPicture!);
    }

    canvas.restore();

    // Log paint call timing
    stopwatch.stop();
    _paintDurations.add(stopwatch.elapsed);
    if (_paintCallCount % 60 == 0) {
      final avgDuration =
          _paintDurations.fold<int>(0, (a, b) => a + b.inMilliseconds) ~/ _paintDurations.length;
      developer.log("Paint call #$_paintCallCount avg: ${avgDuration}ms over 60 calls",
          name: "rubin_chart.perf");
      _paintDurations.clear();
    }
    _paintCallCount++;
  }

  @override
  bool shouldRepaint(SeriesPainter oldDelegate) {
    // Check data and layout
    if (oldDelegate.data != data || oldDelegate.tickLabelMargin != tickLabelMargin) {
      return true;
    }

    // Deep equality check for selections to avoid repaints when contents are identical
    if (!_setsEqual(oldDelegate.selectedDataPoints, selectedDataPoints)) {
      return true;
    }

    if (!_setsEqual(oldDelegate.drillDownDataPoints, drillDownDataPoints)) {
      return true;
    }

    return false;
  }

  /// Helper to compare sets by content, not reference
  bool _setsEqual(Set<Object> a, Set<Object> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  @override
  bool shouldRebuildSemantics(SeriesPainter oldDelegate) {
    return !_setsEqual(oldDelegate.selectedDataPoints, selectedDataPoints);
  }
}

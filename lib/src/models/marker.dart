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

import "dart:math" as math;
import 'package:flutter/material.dart';

/// The types of markers that can be drawn on a chart.
/// Currently only [circle] markers are supported.
enum MarkerTypes {
  /// A circle marker.
  circle,

  /// A square marker.
  rectangle,

  /// A unicode character as a marker.
  unicode,
}

/// A marker that can be drawn on a chart.
class Marker {
  /// The size of the marker.
  final double size;

  /// The type of marker.
  final MarkerTypes type;

  /// The color of the marker.
  /// If null then the marker will be not be filled in.
  final Color? color;

  /// The color of the edge of the marker.
  /// If null then the marker will not have an edge.
  final Color? edgeColor;

  const Marker({
    this.size = 5,
    this.color = Colors.black,
    this.edgeColor = Colors.white,
    this.type = MarkerTypes.circle,
  });

  /// Create a copy of the marker with new values.
  Marker copyWith({
    double? size,
    MarkerTypes? type,
    Color? color,
    Color? edgeColor,
  }) =>
      Marker(
        size: size ?? this.size,
        type: type ?? this.type,
        color: color ?? this.color,
        edgeColor: edgeColor ?? this.edgeColor,
      );

  /// Paint a marker on the [Canvas] at a given [math.Point].
  void paint(Canvas canvas, Paint? paintFill, Paint? paintEdge, Offset point) {
    // TODO: support marker types other than circles
    if (type == MarkerTypes.circle) {
      if (paintFill != null) {
        canvas.drawCircle(Offset(point.dx, point.dy), size, paintFill);
      }
      if (paintEdge != null) {
        canvas.drawCircle(Offset(point.dx, point.dy), size, paintEdge);
      }
    } else {
      throw UnimplementedError("Only circle markers are supported at this time");
    }
  }
}

/// A class for drawing error bars on a chart.
class ErrorBars {
  /// The width of the line drawing the error bars.
  final double width;

  /// The size of the head of the error bars.
  final double headSize;

  /// The color of the error bars.
  final Color color;

  const ErrorBars({
    this.width = 2,
    this.color = Colors.black,
    this.headSize = 20,
  });

  /// Create a copy of the error bars with new values.
  ErrorBars copyWith({
    double? width,
    Color? color,
    double? headSize,
  }) =>
      ErrorBars(
        width: width ?? this.width,
        color: color ?? this.color,
        headSize: headSize ?? this.headSize,
      );
}

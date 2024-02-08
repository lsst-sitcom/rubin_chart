import "dart:math" as math;
import 'package:flutter/material.dart';

enum MarkerTypes {
  circle,
  rectangle,
  unicode,
}

class Marker {
  final double size;
  final MarkerTypes type;
  final Color? color;
  final Color? edgeColor;

  const Marker({
    this.size = 10,
    this.color = Colors.black,
    this.edgeColor = Colors.white,
    this.type = MarkerTypes.circle,
  });

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
        canvas.drawCircle(Offset(point.dx, point.dy), 5, paintFill);
      }
      if (paintEdge != null) {
        canvas.drawCircle(Offset(point.dx, point.dy), 5, paintEdge);
      }
    } else {
      throw UnimplementedError("Only circle markers are supported at this time");
    }
  }
}

class ErrorBars {
  final double width;
  final double headSize;
  final Color color;

  const ErrorBars({
    this.width = 2,
    this.color = Colors.black,
    this.headSize = 20,
  });

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

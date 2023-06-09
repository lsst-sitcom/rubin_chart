import 'package:flutter/material.dart';
import 'package:rubin_chart/src/chart/axis.dart';


enum MarkerTypes {
  circle,
  rectangle,
  unicode,
}


class MarkerSettings {
  final double size;
  final MarkerTypes type;
  final Color color;
  final Color? edgeColor;

  const MarkerSettings({
    this.size = 10,
    this.color = Colors.black,
    this.edgeColor = Colors.white,
    this.type = MarkerTypes.circle,
  });

  MarkerSettings copyWith({
    double? size,
    MarkerTypes? type,
    Color? color,
    Color? edgeColor,
  }) => MarkerSettings(
    size: size ?? this.size,
    type: type ?? this.type,
    color: color ?? this.color,
    edgeColor: edgeColor ?? this.edgeColor,
  );
}


class ErrorBarSettings {
  final double width;
  final double headSize;
  final Color color;

  const ErrorBarSettings({
    this.width = 2,
    this.color = Colors.black,
    this.headSize = 20,
  });

  ErrorBarSettings copyWith({
    double? width,
    Color? color,
    double? headSize,
  }) => ErrorBarSettings(
    width: width ?? this.width,
    color: color ?? this.color,
    headSize: headSize ?? this.headSize,
  );
}



class Marker extends StatelessWidget {
  final double size;
  final MarkerTypes markerType;
  final Color color;
  final Color? edgeColor;
  final double edgeWidth;

  const Marker({
    super.key,
    required this.size,
    required this.color,
    this.edgeColor,
    this.edgeWidth=1,
    this.markerType = MarkerTypes.circle,
  });

  @override
  Widget build(BuildContext context){
    Widget result;

    if(markerType == MarkerTypes.circle){
      result = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
    } else {
      throw UnimplementedError("Marker type $markerType has not yet been implemented");
    }
    return result;
  }
}


/// Error bars for a marker
/// Error bar extends min to negative direction along the axis and max in the positive direction
class ErrorBars extends StatelessWidget {
  final PlotAxis axis;
  final double min;
  final double max;

  const ErrorBars({
    super.key,
    required this.axis,
    required this.min,
    required this.max,
  });

  @override
  Widget build(BuildContext context){
    // TODO: implement error bars
    throw UnimplementedError("ErrorBars have not yet been implemented");
  }
}

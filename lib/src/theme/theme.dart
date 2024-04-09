import 'package:flutter/material.dart';

const List<Color> _defaultColorCycle = [
  Color(0xFFE6194B),
  Color(0xFF3CB44B),
  Color(0xFFFFE119),
  Color(0xFF0082C8),
  Color(0xFFF58231),
  Color(0xFF911EB4),
  Color(0xFF46F0F0),
  Color(0xFFF032E6),
  Color(0xFFD2F53C),
  Color(0xFFFABEBE),
  Color(0xFF008080),
  Color(0xFFE6BEFF),
  Color(0xFFAA6E28),
  Color(0xFFFFFAC8),
  Color(0xFF800000),
  Color(0xFFAAFFC3),
  Color(0xFF808000),
  Color(0xFFFFD8B1),
  Color(0xFF000080),
  Color(0xFF808080),
  Color(0xFFFFFFFF),
  Color(0xFF000000),
];

Color invertColor(Color color) => Color.fromARGB(
      color.alpha,
      255 - color.red,
      255 - color.green,
      255 - color.blue,
    );

@immutable
class ChartTheme {
  final Color? backgroundColor;
  final Color? tickColor;
  final double tickThickness;
  final double majorTickLength;
  final double minorTickLength;
  final TextStyle? tickLabelStyle;
  final TextStyle? axisLabelStyle;
  final Color? gridColor;
  final double gridLineThickness;
  final Color? frameColor;
  final double frameLineThickness;
  final List<Color> colorCycle;
  final int quadTreeDepth;
  final int quadTreeCapacity;
  final TextStyle? titleStyle;
  final Color legendBorderColor;
  final double legendBorderWidth;
  final double legendBorderRadius;
  final TextStyle? legendStyle;

  /// Minimum number of ticks to display on an axis.
  /// This is up to user prefernce, but there should be
  /// enough of a range
  final int minTicks;
  final int maxTicks;

  const ChartTheme({
    this.backgroundColor = Colors.white,
    this.tickColor = Colors.black,
    this.tickThickness = 2,
    this.majorTickLength = 10,
    this.minorTickLength = 5,
    this.tickLabelStyle,
    this.axisLabelStyle,
    this.gridColor = Colors.grey,
    this.gridLineThickness = 1,
    this.frameColor = Colors.black,
    this.frameLineThickness = 2,
    this.colorCycle = _defaultColorCycle,
    this.minTicks = 7,
    this.maxTicks = 15,
    this.quadTreeDepth = 10,
    this.quadTreeCapacity = 10,
    this.titleStyle,
    this.legendBorderColor = Colors.black,
    this.legendBorderWidth = 2,
    this.legendBorderRadius = 10,
    this.legendStyle,
  });

  ChartTheme copyWith({
    Color? backgroundColor,
    Color? tickColor,
    double? tickThickness,
    TextStyle? tickLabelStyle,
    TextStyle? axisLabelStyle,
    Color? gridColor,
    double? gridLineThickness,
    Color? frameColor,
    double? frameLineThickness,
    List<Color>? colorCycle,
  }) {
    return ChartTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      tickColor: tickColor ?? this.tickColor,
      tickThickness: tickThickness ?? this.tickThickness,
      tickLabelStyle: tickLabelStyle ?? this.tickLabelStyle,
      axisLabelStyle: axisLabelStyle ?? this.axisLabelStyle,
      gridColor: gridColor ?? this.gridColor,
      gridLineThickness: gridLineThickness ?? this.gridLineThickness,
      frameColor: frameColor ?? this.frameColor,
      frameLineThickness: frameLineThickness ?? this.frameLineThickness,
      colorCycle: colorCycle ?? this.colorCycle,
    );
  }

  static const ChartTheme defaultTheme = ChartTheme();
  static const ChartTheme darkTheme = ChartTheme(
    backgroundColor: Colors.black,
    tickColor: Colors.white,
    gridColor: Colors.grey,
    frameColor: Colors.white,
  );

  static const defaultColorCycle = _defaultColorCycle;
}

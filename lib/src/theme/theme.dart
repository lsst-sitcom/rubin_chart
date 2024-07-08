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

/// The default color cycle.
/// This is a list of 21 colors that can be distinguished from one another
/// for maximum visibility.
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

/// Invert a color.
Color invertColor(Color color) => Color.fromARGB(
      color.alpha,
      255 - color.red,
      255 - color.green,
      255 - color.blue,
    );

/// A theme for the chart.
@immutable
class ChartTheme {
  /// The background color of the chart.
  final Color? backgroundColor;

  /// The color of the ticks on the chart.
  final Color? tickColor;

  /// The thickness of the ticks on the chart.
  final double tickThickness;

  /// The length of the major ticks on the chart.
  final double majorTickLength;

  /// The length of the minor ticks on the chart.
  final double minorTickLength;

  /// The style of the tick labels.
  final TextStyle? tickLabelStyle;

  /// The style of the axis labels.
  final TextStyle? axisLabelStyle;

  /// The color of the grid lines.
  final Color? gridColor;
  //// The thickness of the grid lines.
  final double gridLineThickness;

  /// The color of the frame.
  final Color? frameColor;

  /// The thickness of the frame.
  final double frameLineThickness;

  /// The color cycle for the chart.
  final List<Color> colorCycle;

  /// The depth of the quad tree.
  final int quadTreeDepth;

  /// The capacity of the quad tree.
  final int quadTreeCapacity;

  /// The style of the title.
  final TextStyle? titleStyle;

  /// The color of the legend border.
  final Color legendBorderColor;

  /// The width of the legend border.
  final double legendBorderWidth;

  /// The radius of the legend border.
  final double legendBorderRadius;

  /// The style of the legend labels.
  final TextStyle? legendStyle;

  /// Minimum number of ticks to display on an axis.
  /// This is up to user prefernce, but there should be
  /// enough of a range
  final int minTicks;

  /// Maximum number of ticks to display on an axis.
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

  /// Create a copy of the theme with new values.
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

  /// The default [ChartTheme].
  static const ChartTheme defaultTheme = ChartTheme();

  /// A dark [ChartTheme].
  static const ChartTheme darkTheme = ChartTheme(
    backgroundColor: Colors.black,
    tickColor: Colors.white,
    gridColor: Colors.grey,
    frameColor: Colors.white,
  );

  /// The default color cycle.
  static const defaultColorCycle = _defaultColorCycle;
}

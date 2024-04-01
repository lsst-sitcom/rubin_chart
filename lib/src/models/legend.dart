import 'package:flutter/widgets.dart';

/// The location of a chart legend.
enum LegendLocation {
  /// The legend is placed above the chart
  top,

  /// The legend is placed below the chart
  bottom,

  /// The legend is placed to the left of the chart
  left,

  /// The legend is placed to the right of the chart
  right,

  /// The legend is placed at a specific offset from the bottom-left corner of the chart
  floating,

  /// The legend is not displayed
  none,
}

/// The legend of a chart
class Legend {
  /// The location of the legend.
  /// Unless [LegendLocation.floating] is used, the legend will be placed
  /// on the side of the chart specified by this value.
  final LegendLocation location;

  /// The offset of the legend from the top-left corner of the chart
  /// if [LegendLocation.floating] is used.
  Offset offset;

  Legend({this.location = LegendLocation.right, this.offset = Offset.zero});
}

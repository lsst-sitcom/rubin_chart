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

typedef NewSeriesCallback = void Function();

/// The legend of a chart
class Legend {
  /// The location of the legend.
  /// Unless [LegendLocation.floating] is used, the legend will be placed
  /// on the side of the chart specified by this value.
  final LegendLocation location;

  /// Whether to include a widget to add new [Series] to the chart.
  final NewSeriesCallback? newSeriesCallback;

  /// The offset of the legend from the top-left corner of the chart
  /// if [LegendLocation.floating] is used.
  Offset offset;

  Legend({this.location = LegendLocation.floating, this.offset = Offset.zero, this.newSeriesCallback});

  /// Whether new [Series] can be added to the chart.
  bool get allowNewSeries => newSeriesCallback != null;
}

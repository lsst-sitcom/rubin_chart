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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rubin_chart/src/models/legend.dart';
import 'package:rubin_chart/src/models/marker.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/ui/chart.dart';

/// A callback function that is called a [Series] in a [Legend] is selected.
typedef LegendSelectionCallback = void Function({required Series series});

typedef LegendPanStartCallback = void Function(DragStartDetails details, LegendViewer legendViewer);

typedef LegendPanUpdateCallback = void Function(DragUpdateDetails details, LegendViewer legendViewer);

typedef LegendPanEndCallback = void Function(DragEndDetails details);

/// A widget that displays a single Series entry in a legend.
class LegendEntry extends StatelessWidget {
  /// The marker for the series.
  /// This may be different than the [series] marker because the
  /// series marker can be null, in which case this is generated
  /// using the color cycle of the [SeriesList].
  final Marker marker;

  /// The text to display for the series.
  final TextSpan textSpan;

  /// The size of the row.
  final Size rowSize;

  /// The theme to use for the legend.
  final ChartTheme theme;

  /// The series that this entry represents.
  final Series series;

  const LegendEntry({
    super.key,
    required this.marker,
    required this.textSpan,
    required this.rowSize,
    required this.theme,
    required this.series,
  });

  /// Initialize a [LegendEntry] with the given parameters.
  static LegendEntry init({
    Key? key,
    required Marker marker,
    required String label,
    required ChartTheme theme,
    required Series series,
  }) {
    TextSpan textSpan = TextSpan(
      text: label,
      style: theme.legendStyle,
    );
    TextPainter textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    Size rowSize = Size(marker.size + textPainter.width + 20, math.max(textPainter.height, marker.size) + 10);

    return LegendEntry(
      marker: marker,
      textSpan: textSpan,
      rowSize: rowSize,
      theme: theme,
      series: series,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: rowSize.width,
      height: rowSize.height,
      child: Row(
        children: [
          const SizedBox(width: 5),
          Container(
            width: marker.size,
            height: marker.size,
            decoration: BoxDecoration(
              color: marker.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          RichText(text: textSpan),
          const SizedBox(width: 5),
        ],
      ),
    );
  }
}

/// A widget that displays a legend for a chart.
abstract class LegendViewer extends StatelessWidget {
  /// The legend to display.
  final Legend legend;

  /// The theme to use for the legend.
  final ChartTheme theme;

  /// The rows to display in the legend.
  final List<LegendEntry> rows;

  /// The size of the legend.
  /// This must be pre-calculated on init from a static method because
  /// it is needed to layout the chart.
  final Size legendSize;

  /// The layout ID for the legend.
  final ChartLayoutId layoutId;

  /// A callback function that is called when a series is selected.
  final LegendSelectionCallback? selectionCallback;

  final LegendPanStartCallback onPanStart;
  final LegendPanUpdateCallback onPanUpdate;
  final LegendPanEndCallback onPanEnd;

  const LegendViewer({
    super.key,
    required this.legend,
    required this.theme,
    required this.rows,
    required this.legendSize,
    required this.layoutId,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    this.selectionCallback,
  });
}

/// A viewer for a horizontal legend.
class VerticalLegendViewer extends LegendViewer {
  const VerticalLegendViewer({
    super.key,
    required super.legend,
    required super.theme,
    required super.rows,
    required super.legendSize,
    required super.layoutId,
    required super.onPanStart,
    required super.onPanUpdate,
    required super.onPanEnd,
    super.selectionCallback,
  });

  /// Create a [VerticalLegendViewer] from a set of parameters.
  static VerticalLegendViewer fromSeriesList({
    Key? key,
    required Legend legend,
    required ChartTheme theme,
    required SeriesList seriesList,
    required ChartLayoutId layoutId,
    required LegendPanStartCallback onPanStart,
    required LegendPanUpdateCallback onPanUpdate,
    required LegendPanEndCallback onPanEnd,
    LegendSelectionCallback? selectionCallback,
  }) {
    List<LegendEntry> rows = [];
    double width = 0;
    double height = 0;
    for (int i = 0; i < seriesList.length; i++) {
      LegendEntry entry = LegendEntry.init(
        marker: seriesList.getMarker(i),
        label: seriesList.values[i].name,
        theme: theme,
        series: seriesList.values[i],
      );
      rows.add(entry);
      width = math.max(width, entry.rowSize.width);
      height += entry.rowSize.height;
    }
    return VerticalLegendViewer(
      key: key,
      legend: legend,
      theme: theme,
      rows: rows,
      legendSize: Size(width, height),
      layoutId: layoutId,
      selectionCallback: selectionCallback,
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    int numEntries = rows.length;
    if (legend.allowNewSeries) {
      numEntries++;
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.legendBorderColor,
          width: theme.legendBorderWidth,
        ),
        borderRadius: BorderRadius.circular(theme.legendBorderRadius),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (DragStartDetails details) => onPanStart(details, this),
        onPanUpdate: (DragUpdateDetails details) => onPanUpdate(details, this),
        onPanEnd: onPanEnd,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: numEntries,
          itemBuilder: (BuildContext context, int index) {
            if (index == rows.length) {
              return IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                onPressed: () {
                  legend.newSeriesCallback?.call();
                },
              );
            }
            return InkWell(
              onTap: () {
                selectionCallback?.call(series: rows[index].series);
              },
              child: rows[index],
            );
          },
        ),
      ),
    );
  }
}

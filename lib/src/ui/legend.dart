import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rubin_chart/src/models/legend.dart';
import 'package:rubin_chart/src/models/marker.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/ui/chart.dart';

class LegendEntry extends StatelessWidget {
  final Marker marker;
  final TextSpan textSpan;
  final Size rowSize;
  final ChartTheme theme;
  final Series series;

  const LegendEntry({
    super.key,
    required this.marker,
    required this.textSpan,
    required this.rowSize,
    required this.theme,
    required this.series,
  });

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

abstract class LegendViewer extends StatelessWidget {
  final Legend legend;
  final ChartTheme theme;
  final List<LegendEntry> rows;
  final Size legendSize;
  final ChartLayoutId layoutId;
  final SelectionController? selectionController;

  const LegendViewer({
    super.key,
    required this.legend,
    required this.theme,
    required this.rows,
    required this.legendSize,
    required this.layoutId,
    this.selectionController,
  });
}

class VerticalLegendViewer extends LegendViewer {
  const VerticalLegendViewer({
    super.key,
    required super.legend,
    required super.theme,
    required super.rows,
    required super.legendSize,
    required super.layoutId,
    super.selectionController,
  });

  static VerticalLegendViewer fromSeriesList({
    Key? key,
    required Legend legend,
    required ChartTheme theme,
    required SeriesList seriesList,
    required ChartLayoutId layoutId,
    SelectionController? selectionController,
  }) {
    List<LegendEntry> rows = [];
    double width = 0;
    double height = 0;
    for (int i = 0; i < seriesList.length; i++) {
      LegendEntry entry = LegendEntry.init(
        marker: seriesList.getMarker(i),
        label: seriesList.values[i].name ?? "Series $i",
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
      selectionController: selectionController,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.legendBorderColor,
          width: theme.legendBorderWidth,
        ),
        borderRadius: BorderRadius.circular(theme.legendBorderRadius),
      ),
      child: ListView.builder(
        itemCount: rows.length,
        itemBuilder: (BuildContext context, int index) {
          return InkWell(
            onTap: () {
              selectionController?.updateSelection(
                  null, rows[index].series.data.data.values.first.keys.toSet());
            },
            child: rows[index],
          );
        },
      ),
    );
  }
}

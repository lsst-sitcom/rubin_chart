import 'package:flutter/material.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/projection.dart';
import 'package:rubin_chart/src/models/legend.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/ui/chart.dart';
import 'package:rubin_chart/src/ui/legend.dart';

class CartesianChart extends StatelessWidget {
  final String? title;
  final ChartTheme theme;
  final SeriesList seriesList;
  final Legend? legend;
  final List<ChartAxisInfo>? axisInfo;

  const CartesianChart({
    super.key,
    this.title,
    required this.theme,
    required this.seriesList,
    required this.legend,
    this.axisInfo,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];

    if (title != null) {
      children.add(
        LayoutId(
          id: ChartComponent.title,
          child: Text(
            title!,
            style: theme.titleStyle,
          ),
        ),
      );
    }

    if (legend != null) {
      if (legend!.location == LegendLocation.left || legend!.location == LegendLocation.right) {
        children.add(
          LayoutId(
            id: legend!.location,
            child: VerticalLegendViewer(
              legend: legend!,
              theme: theme,
              seriesList: seriesList,
            ),
          ),
        );
      } else {
        throw UnimplementedError("Horizontal legends are not yet implemented.");
      }
    }

    //Map<int, List<ChartAxisInfo>> axesInfo = getAxisInfoFromSeries(seriesList);

    return CustomMultiChildLayout(
      delegate: ChartLayoutDelegate(),
      children: children,
    );
  }
}

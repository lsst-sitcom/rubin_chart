import 'package:flutter/material.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/legend.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/ui/chart.dart';
import 'package:rubin_chart/src/ui/charts/scatter.dart';
import 'package:rubin_chart/src/ui/legend.dart';

/// Initialize the basic information about all of the [ChartAxis] instances from a list of [Series].
Map<AxisId<A>, ChartAxisInfo> axisInfoFromSeriesList<C, I, A>(List<Series<C, I, A>> seriesList) {
  Map<AxisId<A>, ChartAxisInfo> axisInfo = {};
  for (Series<C, I, A> series in seriesList) {
    if (!axisInfo.containsKey(series.axesId)) {
      List<ChartAxisInfo> axisInfos = [];
      for (MapEntry<AxisId, C> entry in series.data.plotColumns.entries) {
        axisInfos.add(ChartAxisInfo(
          label: entry.value.toString(),
          location: entry.key.location,
        ));
      }
    }
  }
  return axisInfo;
}

class CartesianChart<C, I, A> extends StatefulWidget {
  final String? title;
  final ChartTheme theme;
  late final SeriesList<C, I, A> seriesList;
  final Legend? legend;
  final Map<AxisId<A>, ChartAxisInfo>? axisInfo;
  final Widget child;

  CartesianChart({
    super.key,
    this.title,
    this.theme = const ChartTheme(),
    required List<Series<C, I, A>> seriesList,
    required this.legend,
    required this.child,
    List<Color>? colorCycle,
    this.axisInfo,
  }) : seriesList = SeriesList<C, I, A>(seriesList, colorCycle ?? theme.colorCycle);

  @override
  State<CartesianChart<C, I, A>> createState() => CartesianChartState<C, I, A>();
}

class CartesianChartState<C, I, A> extends State<CartesianChart<C, I, A>> {
  String? get title => widget.title;
  ChartTheme get theme => widget.theme;
  SeriesList<C, I, A> get seriesList => widget.seriesList;
  Legend? get legend => widget.legend;
  late Map<AxisId<A>, ChartAxisInfo> axisInfo;

  @override
  void initState() {
    super.initState();
    axisInfo = widget.axisInfo ?? axisInfoFromSeriesList(seriesList.values);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];

    if (widget.title != null) {
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

    for (MapEntry<AxisId<A>, ChartAxisInfo> entry in axisInfo.entries) {
      AxisLocation location = entry.value.location;
      ChartAxisInfo axisInfo = entry.value;
      Widget label = Text(axisInfo.label, style: theme.axisLabelStyle);
      ChartComponent component;
      if (location == AxisLocation.left || location == AxisLocation.right) {
        label = RotatedBox(
          quarterTurns: axisInfo.location == AxisLocation.left ? 3 : 1,
          child: label,
        );
        if (location == AxisLocation.left) {
          component = ChartComponent.leftAxis;
        } else {
          component = ChartComponent.rightAxis;
        }
      } else if (location == AxisLocation.bottom) {
        component = ChartComponent.bottomAxis;
      } else if (location == AxisLocation.top) {
        component = ChartComponent.topAxis;
      } else {
        throw AxisUpdateException("Unknown axis location: $location for a cartesian chart");
      }

      children.add(
        LayoutId(
          id: component,
          child: label,
        ),
      );
    }

    children.add(
      LayoutId(
        id: ChartComponent.chart,
        child: widget.child,
      ),
    );

    return CustomMultiChildLayout(
      delegate: ChartLayoutDelegate(),
      children: children,
    );
  }
}

class CartesianScatterChart<C, I, A> extends CartesianChart<C, I, A> {
  CartesianScatterChart({
    super.key,
    required List<Series<C, I, A>> seriesList,
    Map<AxisId<A>, ChartAxisInfo>? axisInfo,
    super.title,
    super.theme,
    super.legend,
  }) : super(
          seriesList: seriesList,
          child: ScatterPlot<C, I, A>(
            theme: theme,
            seriesList: seriesList,
            axisInfo: axisInfo ?? axisInfoFromSeriesList(seriesList),
          ),
          axisInfo: axisInfo ?? axisInfoFromSeriesList(seriesList),
        );
}

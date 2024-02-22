import 'package:flutter/material.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/legend.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/ui/chart.dart';
import 'package:rubin_chart/src/ui/legend.dart';

class CartesianChart<C, I, A> extends StatefulWidget {
  final ChartInfo<C, I, A> info;
  final SelectionController<I>? selectionController;
  final Map<AxisId<A>, AxisController> axisControllers;

  const CartesianChart({
    super.key,
    required this.info,
    this.selectionController,
    this.axisControllers = const {},
  });

  @override
  State<CartesianChart<C, I, A>> createState() => CartesianChartState<C, I, A>();
}

class CartesianChartState<C, I, A> extends State<CartesianChart<C, I, A>> {
  SeriesList<C, I, A> get seriesList => SeriesList(
        widget.info.allSeries,
        widget.info.colorCycle ?? widget.info.theme.colorCycle,
      );

  late Map<AxisId<A>, ChartAxisInfo> axisInfo;

  @override
  void initState() {
    super.initState();
    axisInfo = widget.info.axisInfo;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];

    if (widget.info.title != null) {
      children.add(
        LayoutId(
          id: ChartComponent.title,
          child: Text(
            widget.info.title!,
            style: widget.info.theme.titleStyle,
          ),
        ),
      );
    }

    if (widget.info.legend != null) {
      if (widget.info.legend!.location == LegendLocation.left ||
          widget.info.legend!.location == LegendLocation.right) {
        children.add(
          LayoutId(
            id: widget.info.legend!.location,
            child: VerticalLegendViewer(
              legend: widget.info.legend!,
              theme: widget.info.theme,
              seriesList: seriesList,
            ),
          ),
        );
      } else {
        throw UnimplementedError("Horizontal legends are not yet implemented.");
      }
    }

    for (MapEntry<AxisId<A>, ChartAxisInfo> entry in axisInfo.entries) {
      AxisLocation location = entry.value.axisId.location;
      ChartAxisInfo axisInfo = entry.value;
      Widget label = Text(axisInfo.label, style: widget.info.theme.axisLabelStyle);
      ChartComponent component;
      if (location == AxisLocation.left || location == AxisLocation.right) {
        label = RotatedBox(
          quarterTurns: axisInfo.axisId.location == AxisLocation.left ? 3 : 1,
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
        child: widget.info.builder(
          info: widget.info,
          selectionController: widget.selectionController,
          axesControllers: widget.axisControllers.values.toList(),
        ),
      ),
    );

    return CustomMultiChildLayout(
      delegate: ChartLayoutDelegate(),
      children: children,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/ui/chart.dart';

class CombinedChart<C, I, A> extends StatefulWidget {
  final String? title;
  final SelectionController<I>? selectionController;
  final List<List<ChartInfo<C, I, A>?>> children;
  final ChartTheme theme;

  const CombinedChart({
    Key? key,
    required this.title,
    this.theme = ChartTheme.defaultTheme,
    this.selectionController,
    required this.children,
  }) : super(key: key);

  @override
  CombinedChartState<C, I, A> createState() => CombinedChartState<C, I, A>();
}

class CombinedChartState<C, I, A> extends State<CombinedChart<C, I, A>> {
  final List<List<ChartInfo<C, I, A>>> rows = [];
  final List<List<ChartInfo<C, I, A>>> columns = [];
  final Map<AxisController, List<ChartInfo>> axesControllers = {};
  final List<AxisId<A>> hiddenLabels = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.children.length; i++) {
      rows.add([]);
      for (int j = 0; j < widget.children[i].length; j++) {
        ChartInfo<C, I, A>? info = widget.children[i][j];
        if (info != null) {
          rows[i].add(info);
        }
      }
    }
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].length > 1) {
        List<ChartInfo> axisCharts = [];
        Map<Series<C, I, A>, AxisId<A>> seriesToAxis = {};
        AxisLocation? rowLocation;

        for (int j = 0; j < rows[i].length; j++) {
          ChartInfo<C, I, A> info = rows[i][j];
          for (Series<C, I, A> series in info.allSeries) {
            List<AxisLocation> locations = series.data.plotColumns.keys.map((e) => e.location).toList();
            if (rowLocation == null) {
              if (locations.contains(AxisLocation.left)) {
                if (locations.contains(AxisLocation.right)) {
                  throw AxisUpdateException("Cannot have both left and right axes in the same shared row");
                }
                rowLocation = AxisLocation.left;
              } else if (locations.contains(AxisLocation.right)) {
                rowLocation = AxisLocation.right;
              } else {
                throw AxisUpdateException("No horizontal axis found in the series");
              }
              seriesToAxis[series] = _getAxisId(series, rowLocation);
            } else if (locations.contains(rowLocation)) {
              seriesToAxis[series] = _getAxisId(series, rowLocation);
            } else {
              throw AxisUpdateException("No matching axis for $rowLocation found for series $series");
            }
            if (rowLocation == AxisLocation.left && j > 0) {
              hiddenLabels.add(seriesToAxis[series]!);
            } else if (rowLocation == AxisLocation.right && j < rows[i].length - 1) {
              hiddenLabels.add(seriesToAxis[series]!);
            }
          }
          axisCharts.add(info);
        }
        ChartAxis axis = initializeAxis(
          allSeries: seriesToAxis,
          theme: widget.theme,
          axisInfo: ChartAxisInfo(
            label: "x",
            axisId: AxisId(rowLocation!),
          ),
        );

        AxisController axisController = AxisController(
          bounds: axis.bounds,
          ticks: axis.ticks,
        );

        axesControllers[axisController] = axisCharts;
      }
    }

    for (int i = 0; i < widget.children[0].length; i++) {
      if (columns[i].length > 1) {
        List<ChartInfo> axisCharts = [];
        Map<Series<C, I, A>, AxisId<A>> seriesToAxis = {};
        AxisLocation? columnLocation;

        for (int j = 0; j < columns[i].length; j++) {
          ChartInfo<C, I, A> info = columns[i][j];
          for (Series<C, I, A> series in info.allSeries) {
            List<AxisLocation> locations = series.data.plotColumns.keys.map((e) => e.location).toList();
            if (columnLocation == null) {
              if (locations.contains(AxisLocation.top)) {
                if (locations.contains(AxisLocation.bottom)) {
                  throw AxisUpdateException("Cannot have both top and bottom axes in the same shared column");
                }
                columnLocation = AxisLocation.top;
              } else if (locations.contains(AxisLocation.bottom)) {
                columnLocation = AxisLocation.bottom;
              } else {
                throw AxisUpdateException("No vertical axis found in the series");
              }
              seriesToAxis[series] = _getAxisId(series, columnLocation);
            } else if (locations.contains(columnLocation)) {
              seriesToAxis[series] = _getAxisId(series, columnLocation);
            } else {
              throw AxisUpdateException("No matching axis for $columnLocation found for series $series");
            }
            if (columnLocation == AxisLocation.top && j > 0) {
              hiddenLabels.add(seriesToAxis[series]!);
            } else if (columnLocation == AxisLocation.bottom && j < columns[i].length - 1) {
              hiddenLabels.add(seriesToAxis[series]!);
            }
          }
          axisCharts.add(info);
        }
        ChartAxis axis = initializeAxis(
          allSeries: seriesToAxis,
          theme: widget.theme,
          axisInfo: ChartAxisInfo(
            label: "y",
            axisId: AxisId(columnLocation!),
          ),
        );

        AxisController axisController = AxisController(
          bounds: axis.bounds,
          ticks: axis.ticks,
        );

        axesControllers[axisController] = axisCharts;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomMultiChildLayout(
      delegate: CombinedChartLayoutDelegate(),
    );
  }
}

/// A delegate that lays out the components of a chart.
class CombinedChartLayoutDelegate extends ChartLayoutDelegate {
  @override
  void performLayout(Size size) {
    final Map<ChartComponent, Size> childSizes = {};

    for (ChartComponent component in ChartComponent.values) {
      if (hasChild(component) && component != ChartComponent.chart) {
        childSizes[component] = layoutChild(component, BoxConstraints.loose(size));
      }
    }

    double topHeight = childSizes.entries
        .where((entry) => topComponents.contains(entry.key))
        .fold(0, (double previousValue, entry) => previousValue + entry.value.height);

    double bottomHeight = childSizes.entries
        .where((entry) => bottomComponents.contains(entry.key))
        .fold(0, (double previousValue, entry) => previousValue + entry.value.height);

    double leftWidth = childSizes.entries
        .where((entry) => leftComponents.contains(entry.key))
        .fold(0, (double previousValue, entry) => previousValue + entry.value.width);

    double rightWidth = childSizes.entries
        .where((entry) => rightComponents.contains(entry.key))
        .fold(0, (double previousValue, entry) => previousValue + entry.value.width);

    Size chartSize = Size(
      size.width - leftWidth - rightWidth,
      size.height - topHeight - bottomHeight,
    );

    // Layout the chart
    layoutChild(ChartComponent.chart, BoxConstraints.tight(chartSize));

    // Position all of the components.
    if (hasChild(ChartComponent.title)) {
      positionChild(ChartComponent.title,
          Offset(leftWidth + chartSize.width / 2 - childSizes[ChartComponent.title]!.width / 2, 0));
    }
    if (hasChild(ChartComponent.topLegend)) {
      positionChild(
          ChartComponent.topLegend,
          Offset(leftWidth + chartSize.width / 2 - childSizes[ChartComponent.topLegend]!.width / 2,
              childSizes[ChartComponent.title]?.height ?? 0));
    }
    if (hasChild(ChartComponent.topAxis)) {
      positionChild(
          ChartComponent.topAxis,
          Offset(
              leftWidth + chartSize.width / 2 - childSizes[ChartComponent.topAxis]!.width / 2,
              (childSizes[ChartComponent.title]?.height ?? 0) +
                  (childSizes[ChartComponent.topLegend]?.height ?? 0)));
    }
    if (hasChild(ChartComponent.leftLegend)) {
      positionChild(ChartComponent.leftLegend,
          Offset(0, topHeight + chartSize.height / 2 - childSizes[ChartComponent.leftLegend]!.height / 2));
    }
    if (hasChild(ChartComponent.leftAxis)) {
      positionChild(
          ChartComponent.leftAxis,
          Offset(childSizes[ChartComponent.leftLegend]?.width ?? 0,
              topHeight + chartSize.height / 2 - childSizes[ChartComponent.leftAxis]!.height / 2));
    }

    // The chart always exists
    positionChild(ChartComponent.chart, Offset(leftWidth, topHeight));

    if (hasChild(ChartComponent.rightAxis)) {
      positionChild(
          ChartComponent.rightAxis,
          Offset(leftWidth + chartSize.width,
              topHeight + chartSize.height / 2 - childSizes[ChartComponent.rightAxis]!.height / 2));
    }

    if (hasChild(ChartComponent.rightLegend)) {
      positionChild(
          ChartComponent.rightLegend,
          Offset(leftWidth + chartSize.width + (childSizes[ChartComponent.rightAxis]?.width ?? 0),
              topHeight + chartSize.height / 2 - childSizes[ChartComponent.rightLegend]!.height / 2));
    }

    if (hasChild(ChartComponent.bottomAxis)) {
      positionChild(
          ChartComponent.bottomAxis,
          Offset(leftWidth + chartSize.width / 2 - childSizes[ChartComponent.bottomAxis]!.width / 2,
              topHeight + chartSize.height));
    }

    if (hasChild(ChartComponent.bottomLegend)) {
      positionChild(
          ChartComponent.bottomLegend,
          Offset(leftWidth + chartSize.width / 2 - childSizes[ChartComponent.bottomLegend]!.width / 2,
              topHeight + chartSize.height + (childSizes[ChartComponent.bottomAxis]?.height ?? 0)));
    }
  }

  @override
  bool shouldRelayout(covariant MultiChildLayoutDelegate oldDelegate) {
    // TODO: be smarter about when to re-layout
    // This should only happen when one of the labels or the outer size changes.
    return true;
  }
}

AxisId<A> _getAxisId<C, I, A>(Series<C, I, A> series, AxisLocation location) {
  for (AxisId<A> axisId in series.data.plotColumns.keys) {
    if (axisId.location == location) {
      return axisId;
    }
  }
  throw AxisUpdateException("No axis found in the series");
}

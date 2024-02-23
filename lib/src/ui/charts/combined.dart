import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/ui/chart.dart';

class CombinedChart extends StatefulWidget {
  final String? title;
  final SelectionController? selectionController;
  final List<List<ChartInfo?>> children;
  final ChartTheme theme;

  const CombinedChart({
    Key? key,
    required this.title,
    this.theme = ChartTheme.defaultTheme,
    this.selectionController,
    required this.children,
  }) : super(key: key);

  @override
  CombinedChartState createState() => CombinedChartState();
}

class CombinedChartState extends State<CombinedChart> {
  final List<List<ChartInfo>> rows = [];
  final List<List<ChartInfo>> columns = [];
  final Map<AxisController, List<ChartInfo>> axesControllers = {};
  final List<AxisId> hiddenLabels = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.children.length; i++) {
      rows.add([]);
      for (int j = 0; j < widget.children[i].length; j++) {
        ChartInfo? info = widget.children[i][j];
        if (info != null) {
          rows[i].add(info);
        }
      }
    }
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].length > 1) {
        List<ChartInfo> axisCharts = [];
        Map<Series, AxisId> seriesToAxis = {};
        AxisLocation? rowLocation;

        for (int j = 0; j < rows[i].length; j++) {
          ChartInfo info = rows[i][j];
          for (Series series in info.allSeries) {
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
        Map<Series, AxisId> seriesToAxis = {};
        AxisLocation? columnLocation;

        for (int j = 0; j < columns[i].length; j++) {
          ChartInfo info = columns[i][j];
          for (Series series in info.allSeries) {
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
      delegate: CombinedChartLayoutDelegate(children: widget.children, rows: rows, columns: columns),
    );
  }
}

/// A delegate that lays out the components of a chart.
class CombinedChartLayoutDelegate extends MultiChildLayoutDelegate with ChartLayoutMixin {
  final List<List<ChartInfo?>> children;
  final List<List<ChartInfo>> rows;
  final List<List<ChartInfo>> columns;

  CombinedChartLayoutDelegate({
    required this.children,
    required this.rows,
    required this.columns,
  });

  @override
  void performLayout(Size size) {
    // Get the unique chart ids
    final Set<Object> chartIds = {
      ...rows.expand((e) => e).map((chartInfo) => chartInfo.id),
      ...columns.expand((e) => e).map((chartInfo) => chartInfo.id)
    };
    // Layout each chart internally, calculting the size of each non-chart component.
    Map<ChartLayoutId, Size> componentSizes = {};
    for (Object chartId in chartIds) {
      componentSizes.addAll(calcComponentSizes(chartId, size));
    }

    // Calculate the margin for all of the charts
    // (the space required for labels for the edge charts).
    double left = 0;
    double right = 0;
    double top = 0;
    double bottom = 0;
    for (ChartInfo childInfo in columns[0]) {
      ChartLayoutId id = ChartLayoutId(ChartComponent.leftAxis, childInfo.id);
      if (hasChild(id)) {
        left = math.max(left, componentSizes[id]!.width);
      }
    }
    for (ChartInfo childInfo in columns[columns.length - 1]) {
      ChartLayoutId id = ChartLayoutId(ChartComponent.rightAxis, childInfo.id);
      if (hasChild(id)) {
        right = math.max(right, componentSizes[id]!.width);
      }
    }
    for (ChartInfo childInfo in rows[0]) {
      ChartLayoutId id = ChartLayoutId(ChartComponent.topAxis, childInfo.id);
      if (hasChild(id)) {
        top = math.max(top, componentSizes[id]!.height);
      }
    }
    for (ChartInfo childInfo in rows[rows.length - 1]) {
      ChartLayoutId id = ChartLayoutId(ChartComponent.bottomAxis, childInfo.id);
      if (hasChild(id)) {
        bottom = math.max(bottom, componentSizes[id]!.height);
      }
    }

    // Calculate the size of the charts
    List<double> widths = [];
    List<double> heights = [];
    double totalFlexX = rows.expand((list) => list).fold(0.0, (sum, current) => sum + current.flexX);
    double totalFlexY = columns.expand((list) => list).fold(0.0, (sum, current) => sum + current.flexY);
    for (ChartInfo info in rows.expand((row) => row)) {
      widths.add((size.width - left - right) * info.flexX / totalFlexX);
    }
    for (ChartInfo info in columns.expand((column) => column)) {
      heights.add((size.height - top - bottom) * info.flexY / totalFlexY);
    }

    // Layout the charts
    double offsetY = top;
    for (int i = 0; i < children.length; i++) {
      double offsetX = left;
      for (int j = 0; j < children[i].length; j++) {
        ChartInfo? info = children[i][j];
        if (info != null) {
          Offset offset = Offset(offsetX, offsetY);
          layoutSingleChart(info.id, Size(widths[j], heights[i]), offset, componentSizes);
        }
        offsetX += widths[j];
      }
      offsetY += heights[i];
    }
  }

  @override
  bool shouldRelayout(covariant MultiChildLayoutDelegate oldDelegate) {
    // TODO: be smarter about when to re-layout
    // This should only happen when one of the labels or the outer size changes.
    return true;
  }
}

AxisId _getAxisId(Series series, AxisLocation location) {
  for (AxisId axisId in series.data.plotColumns.keys) {
    if (axisId.location == location) {
      return axisId;
    }
  }
  throw AxisUpdateException("No axis found in the series");
}

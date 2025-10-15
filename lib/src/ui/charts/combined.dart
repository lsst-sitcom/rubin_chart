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

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/legend.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/ui/chart.dart';
import 'package:rubin_chart/src/ui/legend.dart';
import 'package:rubin_chart/src/ui/selection_controller.dart';

/// A chart that combines multiple charts linked by shared axes
class CombinedChart extends StatefulWidget {
  /// The title of the combined chart.
  final String? title;

  /// The selection controller for the chart.
  final SelectionController? selectionController;

  /// The drill down controller for the chart.
  final SelectionController? drillDownController;

  /// The children of the combined chart.
  /// All children in the same row will have their y-axes aligned and shared,
  /// while all children in the same column will have their x-axes aligned and shared.
  /// Use "null" for any elements in the grid that should be empty, for example
  /// `[[A, B], [null,C]]` will align A and B on the y-axis and B and C on the x-axis
  /// with no chart below A.
  final List<List<ChartInfo?>> children;

  /// The theme for the chart.
  final ChartTheme theme;

  /// The callback for legend selection.
  final LegendSelectionCallback? legendSelectionCallback;

  /// The callback for coordinate updates.
  final CoordinateCallback? onCoordinateUpdate;

  final TapAxisCallback? onTapAxis;

  const CombinedChart({
    Key? key,
    this.title,
    this.theme = ChartTheme.defaultTheme,
    this.selectionController,
    this.drillDownController,
    required this.children,
    this.legendSelectionCallback,
    this.onCoordinateUpdate,
    this.onTapAxis,
  }) : super(key: key);

  @override
  CombinedChartState createState() => CombinedChartState();
}

/// The state for the combined chart.
class CombinedChartState extends State<CombinedChart> with RubinChartMixin {
  /// The rows of the chart.
  final List<List<ChartInfo>> rows = [];

  /// The columns of the chart.
  final List<List<ChartInfo>> columns = [];

  /// The controllers for the axes.
  final Map<AxisController, Map<AxisId, ChartInfo>> axesControllers = {};

  /// The hidden labels.
  final List<ChartLayoutId> hiddenLabels = [];

  /// The hidden axes.
  final List<AxisId> hiddenAxes = [];

  @override
  late SelectionController selectionController;
  @override
  SelectionController? drillDownController;
  final Map<ChartInfo, Offset> _initialLegendOffsets = {};
  Offset _cursorOffset = Offset.zero;
  @override
  LegendSelectionCallback? get legendSelectionCallback => widget.legendSelectionCallback;
  @override
  CoordinateCallback? get onCoordinateUpdate => widget.onCoordinateUpdate;
  @override
  StreamController<ResetChartAction>? get resetController => null;
  @override
  TapAxisCallback? get onTapAxis => widget.onTapAxis;

  @override
  void initState() {
    super.initState();
    selectionController = widget.selectionController ?? SelectionController();
    _initAxesAndBins();
  }

  @override
  void didUpdateWidget(CombinedChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initAxesAndBins();
  }

  /// Initialize the axes and bins for the all of the charts.
  void _initAxesAndBins() {
    // Clear the parameters
    rows.clear();
    columns.clear();
    axesControllers.clear();
    hiddenLabels.clear();

    // Add the appropriate [ChartInfo] to each row and column.
    int nRows = widget.children.length;
    int nCols = widget.children[0].length;
    for (int i = 0; i < nRows; i++) {
      rows.add([]);
    }
    for (int i = 0; i < nCols; i++) {
      columns.add([]);
    }
    for (int i = 0; i < widget.children.length; i++) {
      for (int j = 0; j < widget.children[i].length; j++) {
        ChartInfo? info = widget.children[i][j];
        if (info != null) {
          rows[i].add(info);
          columns[j].add(info);
        }
      }
    }

    // Create the x axes.
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].length > 1) {
        Map<AxisId, ChartInfo> axisCharts = {};
        Map<Series, AxisId> seriesToAxis = {};
        AxisLocation? rowLocation;
        AxisId axisId;

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
            } else if (!locations.contains(rowLocation)) {
              throw AxisUpdateException("No matching axis for $rowLocation found for series $series");
            }
            axisId = _getAxisId(series, rowLocation);
            seriesToAxis[series] = axisId;
            if (rowLocation == AxisLocation.left && j > 0 ||
                rowLocation == AxisLocation.right && j < rows[i].length - 1) {
              hiddenLabels.add(ChartLayoutId(ChartComponent.axisFromLocation(axisId.location), info.id));
              hiddenAxes.add(axisId);
            }
            axisCharts[axisId] = info;
          }
        }
        ChartAxis axis = initializeAxis(
          allSeries: seriesToAxis,
          theme: widget.theme,
          axisInfo: ChartAxisInfo(
            label: "x",
            axisId: AxisId(rowLocation!, "dummy"),
          ),
          drillDownDataPoints: drillDownController?.selectedDataPoints ?? {},
        );

        AxisController axisController = AxisController(
          bounds: axis.bounds,
          ticks: axis.ticks,
        );

        axesControllers[axisController] = axisCharts;
      }
    }

    // Create the y axes.
    for (int i = 0; i < columns.length; i++) {
      if (columns[i].length > 1) {
        Map<AxisId, ChartInfo> axisCharts = {};
        Map<Series, AxisId> seriesToAxis = {};
        AxisLocation? columnLocation;
        AxisId axisId;

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
            } else if (!locations.contains(columnLocation)) {
              throw AxisUpdateException("No matching axis for $columnLocation found for series $series");
            }
            axisId = _getAxisId(series, columnLocation);
            seriesToAxis[series] = axisId;
            if (columnLocation == AxisLocation.top && j > 0 ||
                columnLocation == AxisLocation.bottom && j < columns[i].length - 1) {
              hiddenLabels.add(ChartLayoutId(ChartComponent.axisFromLocation(axisId.location), info.id));
              hiddenAxes.add(axisId);
            }
            axisCharts[axisId] = info;
          }
        }
        ChartAxis axis = initializeAxis(
          allSeries: seriesToAxis,
          theme: widget.theme,
          axisInfo: ChartAxisInfo(
            label: "y",
            axisId: AxisId(columnLocation!, "dummy"),
          ),
          drillDownDataPoints: drillDownController?.selectedDataPoints ?? {},
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
    // Map the axis controllers to the axis ids
    Map<AxisId, AxisController> axisControllers = {};
    for (MapEntry<AxisController, Map<AxisId, ChartInfo>> entry in axesControllers.entries) {
      AxisController controller = entry.key;
      for (MapEntry<AxisId, ChartInfo> infoEntry in entry.value.entries) {
        axisControllers[infoEntry.key] = controller;
      }
    }
    // Build the individual charts
    List<Widget> children = [];
    Map<ChartInfo, LegendViewer> legendViewers = {};
    for (ChartInfo? info in widget.children.expand((e) => e)) {
      if (info != null) {
        children.addAll(buildSingleChartChildren(
          chartId: info.id,
          info: info,
          selectionController: selectionController,
          drillDownController: widget.drillDownController,
          axisControllers: axisControllers,
          hidden: hiddenLabels,
          hiddenAxes: hiddenAxes,
          onTapAxis: onTapAxis,
          context: context,
        ));

        if (info.legend != null) {
          if (info.legend!.location == LegendLocation.floating) {
            legendViewers[info] = buildLegendViewer(
              info,
              [],
              info.id,
              (DragStartDetails details, LegendViewer legendViewer) {
                _initialLegendOffsets[info] = legendViewers[info]!.legend.offset;
                _cursorOffset = details.globalPosition;
              },
              (DragUpdateDetails details, LegendViewer legendViewer) {
                Offset offset = details.globalPosition - _cursorOffset + _initialLegendOffsets[info]!;
                legendViewers[info]!.legend.offset = offset;
                setState(() {});
              },
              (DragEndDetails details) {
                _initialLegendOffsets.remove(info);
                _cursorOffset = Offset.zero;
              },
            )!;
          } else {
            throw UnimplementedError("Only floating legends are supported for combined charts");
          }
          children.add(LayoutId(
            id: legendViewers[info]!.layoutId,
            child: legendViewers[info]!,
          ));
        }
      }
    }

    return CustomMultiChildLayout(
      delegate: CombinedChartLayoutDelegate(
        children: widget.children,
        rows: rows,
        columns: columns,
        legendViewers: legendViewers,
      ),
      children: children,
    );
  }
}

/// A delegate that lays out the components of a chart.
class CombinedChartLayoutDelegate extends MultiChildLayoutDelegate with ChartLayoutMixin {
  /// The children of the combined chart.
  final List<List<ChartInfo?>> children;

  /// The rows of the combined chart.
  final List<List<ChartInfo>> rows;

  /// The columns of the combined chart.
  final List<List<ChartInfo>> columns;

  /// The legend viewers for each chart.
  final Map<ChartInfo, LegendViewer> legendViewers;

  CombinedChartLayoutDelegate({
    required this.children,
    required this.rows,
    required this.columns,
    required this.legendViewers,
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
      id = ChartLayoutId(ChartComponent.leftLegend, childInfo.id);
      if (hasChild(id)) {}
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
    double totalFlexX = 0;
    double totalFlexY = 0;
    List<double> flexX = [];
    List<double> flexY = [];
    for (int i = 0; i < rows.length; i++) {
      double flex = rows[i].map((e) => e.flexY).reduce(math.min);
      totalFlexY += flex;
      flexY.add(flex);
    }
    for (int i = 0; i < columns.length; i++) {
      double flex = columns[i].map((e) => e.flexX).reduce(math.min);
      totalFlexX += flex;
      flexX.add(flex);
    }

    for (double flex in flexX) {
      widths.add((size.width - left - right) * flex / totalFlexX);
    }
    for (double flex in flexY) {
      heights.add((size.height - top - bottom) * flex / totalFlexY);
    }

    // Layout the charts
    double offsetY = top;
    for (int i = 0; i < children.length; i++) {
      double offsetX = left;
      for (int j = 0; j < children[i].length; j++) {
        ChartInfo? info = children[i][j];
        if (info != null) {
          Offset offset = Offset(offsetX, offsetY);
          ChartLayoutId legendId = ChartLayoutId(ChartComponent.floatingLegend, info.id);
          Offset? legendOffset;
          if (hasChild(legendId)) {
            double legendWidth = legendViewers[info]!.legendSize.width;
            double legendHeight = math.min(legendViewers[info]!.legendSize.height, heights[i]);
            layoutChild(legendId, BoxConstraints.tight(Size(legendWidth, legendHeight)));
            legendOffset = legendViewers[info]!.legend.offset;
          }
          layoutSingleChart(info.id, Size(widths[j], heights[i]), offset, componentSizes, legendOffset);
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

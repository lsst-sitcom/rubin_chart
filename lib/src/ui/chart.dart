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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rubin_chart/src/models/axes/axes.dart';

import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/legend.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/ui/axis_painter.dart';
import 'package:rubin_chart/src/ui/legend.dart';

/// Function called with the current coordinates of the pointer.
typedef CoordinateCallback = void Function(Map<Object, dynamic> coordinates);

/// The quadrant of a plot in cartesian coordinates.
enum CartesianQuadrant {
  /// Top right quadrant.
  first,

  /// Top left quadrant.
  second,

  /// Bottom left quadrant.
  third,

  /// Bottom right quadrant.
  fourth,
}

/// Get the quadrant of a point in the Cartesian plane.
CartesianQuadrant getQuadrant(double x, double y) {
  if (x >= 0 && y >= 0) {
    return CartesianQuadrant.first;
  } else if (x < 0 && y >= 0) {
    return CartesianQuadrant.second;
  } else if (x < 0 && y < 0) {
    return CartesianQuadrant.third;
  } else {
    return CartesianQuadrant.fourth;
  }
}

/// An exception occured while converting data into dart types.
class ChartInitializationException implements Exception {
  ChartInitializationException(this.message);

  String? message;

  @override
  String toString() => "$runtimeType:\n\t$message";
}

/// Callback when sources are selected or deselected.
typedef SelectDatapointsCallback = void Function(List<Object> dataIds);

/// Callback when a data point is, or set of data points are, selected.
typedef SelectionUpdate = void Function(Set<Object> dataPoints);

/// A controller to manage the selection of data points across multiple series.
class SelectionController {
  /// The selected data points.
  final Map<Object?, Set<Object>> _selectionByChartId = {};

  SelectionController();

  /// Get the selected data points.
  Set<Object> get selectedDataPoints =>
      _selectionByChartId.isEmpty ? {} : _selectionByChartId.values.reduce((a, b) => a.intersection(b));

  /// List of observers that are notified when the selection changes.
  final List<SelectionUpdate> _observers = [];

  /// Subscribe to the selection controller.
  void subscribe(SelectionUpdate observer) {
    _observers.add(observer);
  }

  /// Unsubscribe from the selection controller.
  void unsubscribe(SelectionUpdate observer) {
    _observers.remove(observer);
  }

  /// Notify all observers that the selection has changed.
  void _notifyObservers() {
    for (SelectionUpdate observer in _observers) {
      observer(selectedDataPoints);
    }
  }

  /// Update the selected datapoints.
  void updateSelection(Object? chartId, Set<Object> dataPoints) {
    if (dataPoints.isEmpty) {
      if (_selectionByChartId.containsKey(chartId)) {
        _selectionByChartId.remove(chartId);
      }
    } else {
      _selectionByChartId[chartId] = dataPoints;
    }
    _notifyObservers();
  }
}

/// A mixin that provides access to the series, axes, and legend of a chart.
/// This is made so that a state with a global key can have access to
/// its properties in other widgets.
mixin ChartMixin<T extends StatefulWidget> on State<T> {
  /// All of the series in the chart.
  SeriesList get seriesList;

  /// The axes of the chart.
  Map<Object, ChartAxes> get allAxes;

  /// The selected (and highlighted) data points.
  Set<Object> selectedDataPoints = {};

  /// Exclusive set of data points.
  /// If [drillDownDataPoints] is not empty then
  /// only these data points will be shown.
  Set<Object> drillDownDataPoints = {};

  /// Controllers to synch aligned axes.
  Set<AxisController> axisControllers = {};
}

/// Convert a list of [ChartAxisInfo] or a list of [Series] into a map of [ChartAxisInfo].
Map<AxisId, ChartAxisInfo> _genAxisInfoMap(
  List<ChartAxisInfo>? axisInfo,
  List<Series> allSeries,
) {
  Map<AxisId, ChartAxisInfo> axisInfoMap = {};
  if (axisInfo != null) {
    for (ChartAxisInfo info in axisInfo) {
      axisInfoMap[info.axisId] = info;
    }
  } else {
    axisInfoMap = axisInfoFromSeriesList(allSeries);
  }
  return axisInfoMap;
}

mixin Scrollable2DChartMixin<T extends StatefulWidget> on ChartMixin<T> {
  /// Whether a drag gesture is currently active.
  bool get dragging => dragStart != null;

  /// The location of the pointer when the drag gesture started.
  Offset? dragStart;

  /// The location of the pointer when the drag gesture ended.
  Offset? dragEnd;

  /// The currently pressed key (either "x" or "y") used to scale a single axis.
  LogicalKeyboardKey? scaleShiftKey;

  /// Used to detect key presses if the widget has focus.
  /// This property must be initialized in the initState method to add the listiner.
  /// For some plots, like radial plots, there is only one scaling.
  /// In that case focusNode isn't used.
  final FocusNode focusNode = FocusNode();

  /// Scale an axis, or both axes.
  void onScale(PointerScaleEvent event, AxisPainter axisPainter) {
    for (ChartAxes axes in allAxes.values) {
      if (scaleShiftKey == null) {
        axes.scale(event.scale, event.scale, axisPainter.chartSize);
      } else if (scaleShiftKey == LogicalKeyboardKey.keyX) {
        axes.scale(event.scale, 1, axisPainter.chartSize);
      } else if (scaleShiftKey == LogicalKeyboardKey.keyY) {
        axes.scale(1, event.scale, axisPainter.chartSize);
      }
    }

    setState(() {});
    onAxesUpdate();
  }

  /// Pan the chart.
  void onPan(PointerScrollEvent event, AxisPainter axisPainter) {
    Size chartSize = axisPainter.chartSize;
    if (isShiftKey(scaleShiftKey)) {
      for (ChartAxes axes in allAxes.values) {
        axes.scale(
          1 - event.scrollDelta.dx / chartSize.width,
          1 + event.scrollDelta.dy / chartSize.height,
          chartSize,
        );
      }
    } else {
      for (ChartAxes axes in allAxes.values) {
        axes.translate(event.scrollDelta, chartSize);
      }
    }
    onAxesUpdate();
    setState(() {});
  }

  void onAxesUpdate() {}

  /// Check if a key is the shift key.
  bool isShiftKey(LogicalKeyboardKey? key) {
    return key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.shift;
  }

  /// Whether the shift key is currently pressed.
  bool get isShifting => isShiftKey(scaleShiftKey);

  /// Remove the focus node listener when the widget is disposed.
  @override
  void dispose() {
    focusNode.removeListener(focusNodeListener);
    focusNode.dispose();
    super.dispose();
  }

  /// Handle a pressed key when the widget has focus.
  void focusNodeListener() {
    if (focusNode.hasFocus) {
      focusNode.onKeyEvent = handleKeyEvent;
    } else {
      focusNode.onKeyEvent = null;
    }
  }

  /// Handle a key event.
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      setState(() {
        if (event.logicalKey == LogicalKeyboardKey.keyX ||
            event.logicalKey == LogicalKeyboardKey.keyY ||
            isShiftKey(event.logicalKey)) {
          scaleShiftKey = event.logicalKey;
        }
        if (isShiftKey(event.logicalKey)) {
          scaleShiftKey = event.logicalKey;
        }
      });
    } else if (event is KeyUpEvent) {
      setState(() {
        scaleShiftKey = null;
      });
    }
    return KeyEventResult.ignored;
  }
}

/// Information required to build a chart.
/// All charts accept a [ChartInfo] as a required input.
class ChartInfo {
  /// The ID of the chart.
  final Object id;

  /// The title of the chart.
  final String? title;

  /// The theme of the chart.
  final ChartTheme theme;

  /// All of the series in the chart.
  final List<Series> allSeries;

  /// The legend of the chart.
  final Legend? legend;

  /// Information used to generate the axes of the chart.
  final Map<AxisId, ChartAxisInfo> axisInfo;

  /// The color cycle of the chart.
  /// If this is null then the color cycle from the theme is used.
  final List<Color>? colorCycle;

  /// The builder for the chart.
  /// Each [ChartInfo] instance must have a [ChartBuilder] implemented.
  final ChartBuilder builder;

  /// The location of the interior axis labels.
  final AxisLocation? interiorAxisLabelLocation;

  /// The flex factor of the x-axis.
  final double flexX;

  /// The flex factor of the y-axis.
  final double flexY;

  /// The ratio of the x-axis to the y-axis.
  final double? xToYRatio;

  /// Whether to zoom on drill down.
  final bool zoomOnDrillDown;

  ChartInfo({
    required this.id,
    required this.allSeries,
    this.title,
    this.theme = ChartTheme.defaultTheme,
    required this.builder,
    this.legend,
    List<ChartAxisInfo>? axisInfo,
    this.colorCycle,
    this.interiorAxisLabelLocation,
    this.flexX = 1,
    this.flexY = 1,
    this.xToYRatio,
    this.zoomOnDrillDown = true,
  }) : axisInfo = _genAxisInfoMap(axisInfo, allSeries);

  /// Get the list of series and their marker colors based on the color cycle.
  SeriesList get seriesList => SeriesList(allSeries, colorCycle ?? theme.colorCycle);
}

/// A builder for a chart.
/// This function is usually implemented in a class that inherits from [ChartInfo]
/// so that it can be used to create a new [RubinChart].
typedef ChartBuilder = Widget Function({
  required ChartInfo info,
  Map<AxisId, AxisController>? axisControllers,
  SelectionController? selectionController,
  SelectionController? drillDownController,
  List<AxisId>? hiddenAxes,
  CoordinateCallback? onCoordinateUpdate,
  StreamController<ResetChartAction>? resetController,
});

/// Enum provinding the different components of a chart that might need to be laid out.
enum ChartComponent {
  /// The title of the chart.
  title,

  /// A legend on the top of the chart.
  topLegend,

  /// A legend on the bottom of the chart.
  bottomLegend,

  /// A legend on the left of the chart.
  leftLegend,

  /// A legend on the right of the chart.
  rightLegend,

  /// A floating legend.
  floatingLegend,

  /// An axis on the top of the chart.
  topAxis,

  /// An axis on the bottom of the chart.
  bottomAxis,

  /// An axis on the left of the chart.
  leftAxis,

  /// An axis on the right of the chart.
  rightAxis,

  /// The chart itself.
  chart;

  /// Get the legend [ChartComponent] ID from a [LegendLocation].
  static ChartComponent legendFromLocation(LegendLocation location) {
    switch (location) {
      case LegendLocation.top:
        return ChartComponent.topLegend;
      case LegendLocation.bottom:
        return ChartComponent.bottomLegend;
      case LegendLocation.left:
        return ChartComponent.leftLegend;
      case LegendLocation.right:
        return ChartComponent.rightLegend;
      case LegendLocation.floating:
        return ChartComponent.floatingLegend;
      default:
        throw UnimplementedError("Invalid legend location: $location");
    }
  }

  /// Get an axis [ChartComponent] ID from an [AxisLocation].
  static ChartComponent axisFromLocation(AxisLocation location) {
    switch (location) {
      case AxisLocation.top:
        return ChartComponent.topAxis;
      case AxisLocation.bottom:
        return ChartComponent.bottomAxis;
      case AxisLocation.left:
        return ChartComponent.leftAxis;
      case AxisLocation.right:
        return ChartComponent.rightAxis;
      default:
        throw UnimplementedError("Invalid axis location: $location");
    }
  }
}

enum ChartResetTypes {
  full,
  repaint,
}

class ResetChartAction {
  final ChartResetTypes type;

  ResetChartAction(this.type);
}

/// An ID for a [ChartComponent] in a [MultiChildLayoutDelegate].
/// This is intended to be the ID of a [LayoutId].
class ChartLayoutId {
  /// The location of the component in a chart.
  final ChartComponent component;

  /// The id of this chart component.
  final Object id;

  ChartLayoutId(this.component, [this.id = 0]);

  @override
  bool operator ==(Object other) {
    if (other is ChartLayoutId) {
      return component == other.component && id == other.id;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(component, id);

  @override
  String toString() => "AxisId($component, $id)";
}

/// A widget that displays a single chart.
class RubinChart extends StatefulWidget {
  /// The ID of the chart.
  final Object chartId;

  /// The information about the chart.
  final ChartInfo info;

  /// A controller to manage the selection of data points.
  final SelectionController? selectionController;

  /// A controller to manage the drill down of data points.
  final SelectionController? drillDownController;

  /// A controller to manage the axes of the chart.
  final Map<AxisId, AxisController> axisControllers;

  /// A callback when a legend item is selected.
  final LegendSelectionCallback? legendSelectionCallback;

  /// A callback when the coordinates of the pointer are updated.
  final CoordinateCallback? onCoordinateUpdate;

  /// A controller to reset the chart.
  final StreamController<ResetChartAction>? resetController;

  final TapAxisCallback? onTapAxis;

  const RubinChart({
    super.key,
    required this.info,
    Object? chartId,
    this.selectionController,
    this.drillDownController,
    this.axisControllers = const {},
    this.legendSelectionCallback,
    this.onCoordinateUpdate,
    this.resetController,
    this.onTapAxis,
  }) : chartId = chartId ?? "Chart-0";

  @override
  State<RubinChart> createState() => RubinChartState();
}

/// A mixin that provides access to the [SelectionController], [DrillDownController],
/// [LegendSelectionCallback], and [CoordinateCallback] of a chart.
mixin RubinChartMixin {
  SelectionController? get selectionController;
  SelectionController? get drillDownController;
  LegendSelectionCallback? get legendSelectionCallback;
  CoordinateCallback? get onCoordinateUpdate;
  StreamController<ResetChartAction>? get resetController;
  TapAxisCallback? get onTapAxis;

  /// Build a [LegendViewer] for the chart.
  LegendViewer? buildLegendViewer(
    ChartInfo info,
    List<ChartLayoutId> hidden,
    Object chartId,
    LegendPanStartCallback onPanStart,
    LegendPanUpdateCallback onPanUpdate,
    LegendPanEndCallback onPanEnd,
  ) {
    if (info.legend != null) {
      if (info.legend!.location == LegendLocation.left ||
          info.legend!.location == LegendLocation.right ||
          info.legend!.location == LegendLocation.floating) {
        ChartLayoutId layoutId =
            ChartLayoutId(ChartComponent.legendFromLocation(info.legend!.location), chartId);
        if (!hidden.contains(layoutId)) {
          LegendViewer viewer = VerticalLegendViewer.fromSeriesList(
            legend: info.legend!,
            theme: info.theme,
            seriesList: info.seriesList,
            layoutId: layoutId,
            selectionCallback: legendSelectionCallback,
            onPanStart: onPanStart,
            onPanUpdate: onPanUpdate,
            onPanEnd: onPanEnd,
          );
          return viewer;
        }
      } else {
        throw UnimplementedError("Horizontal legends are not yet implemented.");
      }
    }
    return null;
  }

  /// Build the components of a single chart.
  List<Widget> buildSingleChartChildren({
    required Object chartId,
    required ChartInfo info,
    required SelectionController? selectionController,
    required SelectionController? drillDownController,
    required Map<AxisId, AxisController> axisControllers,
    required TapAxisCallback? onTapAxis,
    required BuildContext context,
    List<ChartLayoutId> hidden = const [],
    List<AxisId> hiddenAxes = const [],
  }) {
    List<Widget> children = [];
    Map<AxisId, ChartAxisInfo> axisInfo = info.axisInfo;

    if (info.title != null) {
      children.add(
        LayoutId(
          id: ChartLayoutId(ChartComponent.title, chartId),
          child: Text(
            info.title!,
            style: info.theme.titleStyle,
          ),
        ),
      );
    }

    for (MapEntry<AxisId, ChartAxisInfo> entry in axisInfo.entries) {
      AxisLocation location = entry.value.axisId.location;
      ChartAxisInfo axisInfo = entry.value;
      Widget label = onTapAxis != null
          ? InkWell(
              onTap: () {
                onTapAxis(axisId: axisInfo.axisId, context: context);
              },
              child: Text(axisInfo.label, style: info.theme.axisLabelStyle),
            )
          : Text(axisInfo.label, style: info.theme.axisLabelStyle);
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
      } else if (location == AxisLocation.radial || location == AxisLocation.angular) {
        // TODO: implement axis labels for radial and angular axes
        //component = ChartComponent.bottomAxis;
        continue;
      } else {
        throw AxisUpdateException("Unknown axis location: $location for a cartesian chart");
      }

      ChartLayoutId layoutId = ChartLayoutId(component, chartId);
      if (!hidden.contains(layoutId)) {
        children.add(
          LayoutId(
            id: layoutId,
            child: label,
          ),
        );
      }
    }

    children.add(
      LayoutId(
        id: ChartLayoutId(ChartComponent.chart, chartId),
        child: info.builder(
          info: info,
          selectionController: selectionController,
          drillDownController: drillDownController,
          axisControllers: axisControllers,
          hiddenAxes: hiddenAxes,
          onCoordinateUpdate: onCoordinateUpdate,
          resetController: resetController,
        ),
      ),
    );

    return children;
  }
}

/// The state of a [RubinChart].
class RubinChartState extends State<RubinChart> with RubinChartMixin {
  /// The initial offset of the legend.
  Offset _initialLegendOffset = Offset.zero;

  /// The offset of the cursor.
  Offset _cursorOffset = Offset.zero;

  @override
  SelectionController? get selectionController => widget.selectionController;
  @override
  SelectionController? get drillDownController => widget.drillDownController;
  @override
  LegendSelectionCallback? get legendSelectionCallback => widget.legendSelectionCallback;
  @override
  CoordinateCallback? get onCoordinateUpdate => widget.onCoordinateUpdate;
  @override
  StreamController<ResetChartAction>? get resetController => widget.resetController;
  @override
  TapAxisCallback? get onTapAxis => widget.onTapAxis;

  @override
  void initState() {
    super.initState();
  }

  void _onPanStart(DragStartDetails details, LegendViewer legendViewer) {
    _initialLegendOffset = legendViewer.legend.offset;
    _cursorOffset = details.globalPosition;
  }

  void _onPanUpdate(DragUpdateDetails details, LegendViewer legendViewer) {
    legendViewer.legend.offset = _initialLegendOffset + details.globalPosition - _cursorOffset;
    setState(() {});
  }

  void _onPanEnd(DragEndDetails details) {
    _initialLegendOffset = Offset.zero;
    _cursorOffset = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = buildSingleChartChildren(
      chartId: widget.chartId,
      info: widget.info,
      selectionController: widget.selectionController,
      drillDownController: widget.drillDownController,
      axisControllers: widget.axisControllers,
      onTapAxis: onTapAxis,
      context: context,
    );

    LegendViewer? legendViewer;

    if (widget.info.legend != null) {
      legendViewer = buildLegendViewer(widget.info, [], widget.chartId, _onPanStart, _onPanUpdate, _onPanEnd);
      if (legendViewer != null) {
        children.add(LayoutId(
          id: legendViewer.layoutId,
          child: legendViewer,
        ));
      }
    }
    return CustomMultiChildLayout(
      delegate: ChartLayoutDelegate(
        chartId: widget.chartId,
        xToYRatio: widget.info.xToYRatio,
        legendViewer: legendViewer,
      ),
      children: children,
    );
  }
}

/// A layout for a chart.
class ChartLayout {
  /// The margin of the chart.
  final EdgeInsets margin;

  /// The offsets of the components of the chart.
  final Map<ChartLayoutId, Offset> componentOffsets;

  /// The sizes of the components of the chart.
  final Map<ChartLayoutId, Size> componentSizes;

  ChartLayout({
    required this.margin,
    required this.componentOffsets,
    required this.componentSizes,
  });
}

/// A mixin that lays out the components of a chart.
mixin ChartLayoutMixin implements MultiChildLayoutDelegate {
  /// The layouts of the charts.
  Map<Object, ChartLayout> componentLayouts = {};

  /// The components on the left of the chart.
  List<ChartComponent> get leftComponents => [
        ChartComponent.leftLegend,
        ChartComponent.leftAxis,
      ];

  /// The components on the right of the chart.
  List<ChartComponent> get rightComponents => [
        ChartComponent.rightLegend,
        ChartComponent.rightAxis,
      ];

  /// The components on the top of the chart.
  List<ChartComponent> get topComponents => [
        ChartComponent.title,
        ChartComponent.topLegend,
        ChartComponent.topAxis,
      ];

  /// The components on the bottom of the chart.
  List<ChartComponent> get bottomComponents => [
        ChartComponent.bottomLegend,
        ChartComponent.bottomAxis,
      ];

  /// The components that are legends.
  List<ChartComponent> get legendComponents => [
        ChartComponent.topLegend,
        ChartComponent.bottomLegend,
        ChartComponent.leftLegend,
        ChartComponent.rightLegend,
        ChartComponent.floatingLegend,
      ];

  /// Layout the components of a chart to calculate their sizes
  /// (positions will be calculated later).
  Map<ChartLayoutId, Size> calcComponentSizes(Object chartId, Size size) {
    final Map<ChartLayoutId, Size> componentSizes = {};

    for (ChartComponent component in ChartComponent.values) {
      ChartLayoutId id = ChartLayoutId(component, chartId);
      if (hasChild(id) && component != ChartComponent.chart && !legendComponents.contains(component)) {
        componentSizes[id] = layoutChild(id, BoxConstraints.loose(size));
      }
    }

    return componentSizes;
  }

  /// Calculate the margin for a single chart.
  /// This is the space required for the axis lables and legend.
  EdgeInsets calcSingleChartMargin(Map<ChartLayoutId, Size> componentSizes) {
    double top = componentSizes.entries
        .where((entry) => topComponents.contains(entry.key.component))
        .fold(0, (double previousValue, entry) => previousValue + entry.value.height);

    double bottom = componentSizes.entries
        .where((entry) => bottomComponents.contains(entry.key.component))
        .fold(0, (double previousValue, entry) => previousValue + entry.value.height);

    double left = componentSizes.entries
        .where((entry) => leftComponents.contains(entry.key.component))
        .fold(0, (double previousValue, entry) => previousValue + entry.value.width);

    double right = componentSizes.entries
        .where((entry) => rightComponents.contains(entry.key.component))
        .fold(0, (double previousValue, entry) => previousValue + entry.value.width);

    return EdgeInsets.fromLTRB(left, top, right, bottom);
  }

  /// Layout a single chart.
  void layoutSingleChart(
    Object chartId,
    Size chartSize,
    Offset offset,
    Map<ChartLayoutId, Size> childSizes,
    Offset? legendOffset,
  ) {
    // Layout the chart
    layoutChild(ChartLayoutId(ChartComponent.chart, chartId), BoxConstraints.tight(chartSize));
    Size? titleSize = childSizes[ChartLayoutId(ChartComponent.title, chartId)];
    Size? topLegendSize = childSizes[ChartLayoutId(ChartComponent.topLegend, chartId)];
    Size? topAxisSize = childSizes[ChartLayoutId(ChartComponent.topAxis, chartId)];
    Size? leftLegendSize = childSizes[ChartLayoutId(ChartComponent.leftLegend, chartId)];
    Size? leftAxisSize = childSizes[ChartLayoutId(ChartComponent.leftAxis, chartId)];
    Size? rightAxisSize = childSizes[ChartLayoutId(ChartComponent.rightAxis, chartId)];
    //Size? rightLegendSize = childSizes[ChartLayoutId(ChartComponent.rightLegend, chartId)];
    Size? bottomAxisSize = childSizes[ChartLayoutId(ChartComponent.bottomAxis, chartId)];
    //Size? bottomLegendSize = childSizes[ChartLayoutId(ChartComponent.bottomLegend, chartId)];

    for (ChartComponent component in ChartComponent.values) {
      ChartLayoutId id = ChartLayoutId(component, chartId);
      if (hasChild(id)) {
        switch (id.component) {
          case ChartComponent.title:
            positionChild(id, Offset(offset.dx + chartSize.width / 2 - childSizes[id]!.width / 2, 0));
            break;
          case ChartComponent.topLegend:
            positionChild(id,
                Offset(offset.dx + chartSize.width / 2 - childSizes[id]!.width / 2, titleSize?.height ?? 0));
            break;
          case ChartComponent.topAxis:
            positionChild(
                id,
                Offset(offset.dx + chartSize.width / 2 - childSizes[id]!.width / 2,
                    (titleSize?.height ?? 0) + (topLegendSize?.height ?? 0)));
            break;
          case ChartComponent.leftLegend:
            positionChild(id, Offset(0, offset.dy + chartSize.height / 2 - childSizes[id]!.height / 2));
            break;
          case ChartComponent.leftAxis:
            positionChild(
                id,
                Offset(leftLegendSize?.width ?? 0,
                    offset.dy + chartSize.height / 2 - childSizes[id]!.height / 2));
            break;
          case ChartComponent.rightAxis:
            positionChild(
                id,
                Offset(
                    offset.dx + chartSize.width + (leftLegendSize?.width ?? 0) + (leftAxisSize?.width ?? 0),
                    offset.dy + chartSize.height / 2 - childSizes[id]!.height / 2));
            break;
          case ChartComponent.rightLegend:
            positionChild(
                id,
                Offset(offset.dx + chartSize.width + (leftAxisSize?.width ?? 0) + (rightAxisSize?.width ?? 0),
                    offset.dy + chartSize.height / 2 - childSizes[id]!.height / 2));
            break;
          case ChartComponent.floatingLegend:
            legendOffset ??= Offset.zero;
            positionChild(id, offset + const Offset(100, 10) + legendOffset);
            break;
          case ChartComponent.bottomAxis:
            positionChild(
                id,
                Offset(
                    offset.dx + chartSize.width / 2 - childSizes[id]!.width / 2,
                    offset.dy +
                        chartSize.height +
                        (titleSize?.height ?? 0) +
                        (topLegendSize?.height ?? 0) +
                        (topAxisSize?.height ?? 0)));
            break;
          case ChartComponent.bottomLegend:
            positionChild(
                id,
                Offset(
                    offset.dx + chartSize.width / 2 - childSizes[id]!.width / 2,
                    offset.dy +
                        chartSize.height +
                        (titleSize?.height ?? 0) +
                        (topLegendSize?.height ?? 0) +
                        (topAxisSize?.height ?? 0) +
                        (bottomAxisSize?.height ?? 0)));
            break;
          case ChartComponent.chart:
            positionChild(id, offset);
            break;
        }
      }
    }
  }
}

/// A delegate that lays out the components of a chart.
class ChartLayoutDelegate extends MultiChildLayoutDelegate with ChartLayoutMixin {
  final Object chartId;
  final double? xToYRatio;
  final LegendViewer? legendViewer;

  ChartLayoutDelegate({
    required this.chartId,
    required this.xToYRatio,
    this.legendViewer,
  });

  @override
  void performLayout(Size size) {
    // Calculate the size of each component (other than the chart)
    Map<ChartLayoutId, Size> componentSizes = calcComponentSizes(chartId, size);
    // Calculate the margin required to fit the chart and its labels
    EdgeInsets margin = calcSingleChartMargin(componentSizes);

    // If the user specified a ratio, use it to determine the width and height
    double width = size.width - margin.left - margin.right;
    double height = size.height - margin.top - margin.bottom;
    double fullWidth = width;
    double fullHeight = height;

    // Calcualte the size of the legend (if there is one)
    Offset? legendOffset;
    if (legendViewer != null) {
      double legendWidth = legendViewer!.legendSize.width;
      double legendHeight = legendViewer!.legendSize.height;
      if (legendHeight > height) {
        legendHeight = height;
      }
      layoutChild(legendViewer!.layoutId, BoxConstraints.tight(Size(legendWidth, legendHeight)));
      if (legendViewer!.layoutId.component == ChartComponent.leftLegend ||
          legendViewer!.layoutId.component == ChartComponent.rightLegend) {
        width = width - legendWidth;
        fullWidth = fullWidth - legendWidth;
      }
      componentSizes[legendViewer!.layoutId] = Size(legendWidth, legendHeight);
      legendOffset = legendViewer!.legend.offset;
    }

    if (xToYRatio != null) {
      // Make the height and width proportional
      double proportionalWidth = width;
      double proportionalHeight = height;
      if (width / height > xToYRatio!) {
        proportionalWidth = height * xToYRatio!;
      } else {
        proportionalHeight = width / xToYRatio!;
      }

      // Make sure that the chart fits within the available space
      if (proportionalWidth > width) {
        proportionalWidth = width;
        proportionalHeight = width / xToYRatio!;
      } else if (proportionalHeight > height) {
        proportionalHeight = height;
        proportionalWidth = height * xToYRatio!;
      }
      width = proportionalWidth;
      height = proportionalHeight;
    }
    // Calculate the extra margin required to center the chart
    EdgeInsets extraMargin = EdgeInsets.only(left: (fullWidth - width) / 2, top: (fullHeight - height) / 2);

    Size chartSize = Size(width, height);

    // Position the chart and its labels
    layoutSingleChart(chartId, chartSize,
        Offset(margin.left + extraMargin.left, margin.top + extraMargin.top), componentSizes, legendOffset);
  }

  @override
  bool shouldRelayout(covariant MultiChildLayoutDelegate oldDelegate) {
    // TODO: be smarter about when to re-layout
    // This should only happen when one of the labels or the outer size changes.
    return true;
  }
}

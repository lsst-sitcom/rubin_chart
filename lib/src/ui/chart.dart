import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/projection.dart';
import 'package:rubin_chart/src/models/legend.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/ui/legend.dart';

/// Callback when sources are selected or deselected.
typedef SelectDatapointsCallback = void Function(List<Object> dataIds);

/// A controller to manage the selection of data points across multiple series.
class SelectionController {
  /// The selected data points.
  final List<Object> _selectedDataPoints = [];

  SelectionController();

  /// Get the selected data points.
  List<Object> get selectedDataPoints => [..._selectedDataPoints];

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
  void updateSelection(List<Object> dataPoints) {
    _selectedDataPoints.clear();
    _selectedDataPoints.addAll(dataPoints);
    _notifyObservers();
  }
}

/// A mixin that provides access to the series, axes, and legend of a chart.
/// This is made so that a state with a global key can have access to
/// its properties in other widgets.
mixin ChartMixin<T extends StatefulWidget, U> on State<T> {
  SeriesList get seriesList;
  Map<U, ChartAxes> get axes;
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

/// Information required to build a chart.
/// All charts accept a [ChartInfo] as a required input.
class ChartInfo {
  final Object id;
  final String? title;
  final ChartTheme theme;
  final List<Series> allSeries;
  final Legend? legend;
  final Map<AxisId, ChartAxisInfo> axisInfo;
  final List<Color>? colorCycle;
  final ProjectionInitializer projectionInitializer;
  final ChartBuilder builder;
  final AxisLocation? interiorAxisLabelLocation;
  final double flexX;
  final double flexY;

  ChartInfo({
    required this.id,
    required this.allSeries,
    this.title,
    this.theme = ChartTheme.defaultTheme,
    required this.projectionInitializer,
    required this.builder,
    this.legend,
    List<ChartAxisInfo>? axisInfo,
    this.colorCycle,
    this.interiorAxisLabelLocation,
    this.flexX = 1,
    this.flexY = 1,
  }) : axisInfo = _genAxisInfoMap(axisInfo, allSeries);

  SeriesList get seriesList => SeriesList(allSeries, colorCycle ?? theme.colorCycle);
}

typedef ChartBuilder = Widget Function({
  required ChartInfo info,
  List<AxisController>? axesControllers,
  SelectionController? selectionController,
});

/// Enum provinding the different components of a chart that might need to be laid out.
enum ChartComponent {
  title,
  topLegend,
  bottomLegend,
  leftLegend,
  rightLegend,
  topAxis,
  bottomAxis,
  leftAxis,
  rightAxis,
  chart;

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
      default:
        throw UnimplementedError("Invalid legend location: $location");
    }
  }

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

class RubinChart extends StatefulWidget {
  final Object chartId;
  final ChartInfo info;
  final SelectionController? selectionController;
  final Map<AxisId, AxisController> axisControllers;

  const RubinChart({
    super.key,
    required this.info,
    Object? chartId,
    this.selectionController,
    this.axisControllers = const {},
  }) : chartId = chartId ?? "Chart-0";

  @override
  State<RubinChart> createState() => RubinChartState();
}

mixin RubinChartMixin {
  List<Widget> buildSingleChartChildren({
    required Object chartId,
    required ChartInfo info,
    required SelectionController? selectionController,
    required Map<AxisId, AxisController> axisControllers,
    List<ChartLayoutId> hidden = const [],
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

    if (info.legend != null) {
      if (info.legend!.location == LegendLocation.left || info.legend!.location == LegendLocation.right) {
        ChartLayoutId layoutId =
            ChartLayoutId(ChartComponent.legendFromLocation(info.legend!.location), chartId);
        if (!hidden.contains(layoutId)) {
          children.add(
            LayoutId(
              id: layoutId,
              child: VerticalLegendViewer(
                legend: info.legend!,
                theme: info.theme,
                seriesList: info.seriesList,
              ),
            ),
          );
        }
      } else {
        throw UnimplementedError("Horizontal legends are not yet implemented.");
      }
    }

    for (MapEntry<AxisId, ChartAxisInfo> entry in axisInfo.entries) {
      AxisLocation location = entry.value.axisId.location;
      ChartAxisInfo axisInfo = entry.value;
      Widget label = Text(axisInfo.label, style: info.theme.axisLabelStyle);
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
          axesControllers: axisControllers.values.toList(),
        ),
      ),
    );

    return children;
  }
}

class RubinChartState extends State<RubinChart> with RubinChartMixin {
  @override
  Widget build(BuildContext context) {
    return CustomMultiChildLayout(
      delegate: ChartLayoutDelegate(chartId: widget.chartId),
      children: buildSingleChartChildren(
        chartId: widget.chartId,
        info: widget.info,
        selectionController: widget.selectionController,
        axisControllers: widget.axisControllers,
      ),
    );
  }
}

class ChartLayout {
  final EdgeInsets margin;
  final Map<ChartLayoutId, Offset> componentOffsets;
  final Map<ChartLayoutId, Size> componentSizes;

  ChartLayout({
    required this.margin,
    required this.componentOffsets,
    required this.componentSizes,
  });
}

mixin ChartLayoutMixin implements MultiChildLayoutDelegate {
  Map<Object, ChartLayout> componentLayouts = {};

  List<ChartComponent> get leftComponents => [
        ChartComponent.leftLegend,
        ChartComponent.leftAxis,
      ];

  List<ChartComponent> get rightComponents => [
        ChartComponent.rightLegend,
        ChartComponent.rightAxis,
      ];

  List<ChartComponent> get topComponents => [
        ChartComponent.title,
        ChartComponent.topLegend,
        ChartComponent.topAxis,
      ];

  List<ChartComponent> get bottomComponents => [
        ChartComponent.bottomLegend,
        ChartComponent.bottomAxis,
      ];

  Map<ChartLayoutId, Size> calcComponentSizes(Object chartId, Size size) {
    final Map<ChartLayoutId, Size> componentSizes = {};

    for (ChartComponent component in ChartComponent.values) {
      ChartLayoutId id = ChartLayoutId(component, chartId);
      if (hasChild(id) && component != ChartComponent.chart) {
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
  void layoutSingleChart(Object chartId, Size chartSize, Offset offset, Map<ChartLayoutId, Size> childSizes) {
    // Layout the chart
    layoutChild(ChartLayoutId(ChartComponent.chart, chartId), BoxConstraints.tight(chartSize));

    for (ChartComponent component in ChartComponent.values) {
      ChartLayoutId id = ChartLayoutId(component, chartId);
      if (hasChild(id)) {
        switch (id.component) {
          case ChartComponent.title:
            positionChild(id, Offset(offset.dx + chartSize.width / 2 - childSizes[id]!.width / 2, 0));
            break;
          case ChartComponent.topLegend:
            positionChild(
                id,
                Offset(offset.dx + chartSize.width / 2 - childSizes[id]!.width / 2,
                    childSizes[ChartComponent.title]?.height ?? 0));
            break;
          case ChartComponent.topAxis:
            positionChild(
                id,
                Offset(
                    offset.dx + chartSize.width / 2 - childSizes[id]!.width / 2,
                    (childSizes[ChartComponent.title]?.height ?? 0) +
                        (childSizes[ChartComponent.topLegend]?.height ?? 0)));
            break;
          case ChartComponent.leftLegend:
            positionChild(id, Offset(0, offset.dy + chartSize.height / 2 - childSizes[id]!.height / 2));
            break;
          case ChartComponent.leftAxis:
            positionChild(
                id,
                Offset(childSizes[ChartComponent.leftLegend]?.width ?? 0,
                    offset.dy + chartSize.height / 2 - childSizes[id]!.height / 2));
            break;
          case ChartComponent.rightAxis:
            positionChild(
                id,
                Offset(offset.dx + chartSize.width,
                    offset.dy + chartSize.height / 2 - childSizes[id]!.height / 2));
            break;
          case ChartComponent.rightLegend:
            positionChild(
                id,
                Offset(offset.dx + chartSize.width + (childSizes[ChartComponent.rightAxis]?.width ?? 0),
                    offset.dy + chartSize.height / 2 - childSizes[id]!.height / 2));
            break;
          case ChartComponent.bottomAxis:
            positionChild(
                id,
                Offset(offset.dx + chartSize.width / 2 - childSizes[id]!.width / 2,
                    offset.dy + chartSize.height));
            break;
          case ChartComponent.bottomLegend:
            positionChild(
                id,
                Offset(offset.dx + chartSize.width / 2 - childSizes[id]!.width / 2,
                    offset.dy + chartSize.height + (childSizes[ChartComponent.bottomAxis]?.height ?? 0)));
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
  Object chartId;

  ChartLayoutDelegate({required this.chartId});

  @override
  void performLayout(Size size) {
    Map<ChartLayoutId, Size> componentSizes = calcComponentSizes(chartId, size);
    EdgeInsets margin = calcSingleChartMargin(componentSizes);

    Size chartSize = Size(
      size.width - margin.left - margin.right,
      size.height - margin.top - margin.bottom,
    );

    // Position the chart and its labels
    layoutSingleChart(chartId, chartSize, Offset(margin.left, margin.top), componentSizes);
  }

  @override
  bool shouldRelayout(covariant MultiChildLayoutDelegate oldDelegate) {
    // TODO: be smarter about when to re-layout
    // This should only happen when one of the labels or the outer size changes.
    return true;
  }
}

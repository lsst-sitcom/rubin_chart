import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/projection.dart';
import 'package:rubin_chart/src/models/legend.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';
import 'package:rubin_chart/src/ui/legend.dart';

/// Callback when sources are selected or deselected.
typedef SelectDatapointsCallback = void Function<T>(List<T> dataIds);

/// A controller to manage the selection of data points across multiple series.
class SelectionController<I> {
  /// The selected data points.
  final List<I> _selectedDataPoints = [];

  SelectionController();

  /// Get the selected data points.
  List<I> get selectedDataPoints => [..._selectedDataPoints];

  /// List of observers that are notified when the selection changes.
  final List<SelectionUpdate<I>> _observers = [];

  /// Subscribe to the selection controller.
  void subscribe(SelectionUpdate<I> observer) {
    _observers.add(observer);
  }

  /// Unsubscribe from the selection controller.
  void unsubscribe(SelectionUpdate<I> observer) {
    _observers.remove(observer);
  }

  /// Notify all observers that the selection has changed.
  void _notifyObservers() {
    for (SelectionUpdate<I> observer in _observers) {
      observer(selectedDataPoints);
    }
  }

  /// Update the selected datapoints.
  void updateSelection(List<I> dataPoints) {
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
Map<AxisId<A>, ChartAxisInfo<A>> _genAxisInfoMap<C, I, A>(
  List<ChartAxisInfo<A>>? axisInfo,
  List<Series<C, I, A>> allSeries,
) {
  Map<AxisId<A>, ChartAxisInfo<A>> axisInfoMap = {};
  if (axisInfo != null) {
    for (ChartAxisInfo<A> info in axisInfo) {
      axisInfoMap[info.axisId] = info;
    }
  } else {
    axisInfoMap = axisInfoFromSeriesList(allSeries);
  }
  return axisInfoMap;
}

/// Information required to build a chart.
/// All charts accept a [ChartInfo] as a required input.
class ChartInfo<C, I, A> {
  final String? title;
  final ChartTheme theme;
  final List<Series<C, I, A>> allSeries;
  final Legend? legend;
  final Map<AxisId<A>, ChartAxisInfo<A>> axisInfo;
  final List<Color>? colorCycle;
  final ProjectionInitializer projectionInitializer;
  final ChartBuilder<C, I, A> builder;
  final AxisLocation? interiorAxisLabelLocation;

  ChartInfo({
    required this.allSeries,
    this.title,
    this.theme = ChartTheme.defaultTheme,
    required this.projectionInitializer,
    required this.builder,
    this.legend,
    List<ChartAxisInfo<A>>? axisInfo,
    this.colorCycle,
    this.interiorAxisLabelLocation,
  }) : axisInfo = _genAxisInfoMap(axisInfo, allSeries);

  SeriesList<C, I, A> get seriesList => SeriesList<C, I, A>(allSeries, colorCycle ?? theme.colorCycle);
}

typedef ChartBuilder<C, I, A> = Widget Function({
  required ChartInfo<C, I, A> info,
  List<AxisController>? axesControllers,
  SelectionController<I>? selectionController,
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

  static ChartComponent? legendFromLocation(LegendLocation location) {
    if (location == LegendLocation.top) {
      return ChartComponent.topLegend;
    }
    if (location == LegendLocation.bottom) {
      return ChartComponent.bottomLegend;
    }
    if (location == LegendLocation.left) {
      return ChartComponent.leftLegend;
    }
    if (location == LegendLocation.right) {
      return ChartComponent.rightLegend;
    }
    if (location == LegendLocation.floating) {
      throw UnimplementedError("Floating legends are not yet implemented.");
    }
    if (location == LegendLocation.none) {
      return null;
    }
    throw UnimplementedError("Invalid legend location: $location");
  }
}

/// An ID for a [ChartComponent] in a [MultiChildLayoutDelegate].
/// This is intended to be the ID of a [LayoutId].
class ChartLayoutId<T> {
  /// The location of the component in a chart.
  final ChartComponent component;

  /// The id of this chart component.
  final T id;

  ChartLayoutId._(this.component, this.id);

  /// Create an [AxisId] from a location and (optional) chart ID.
  factory ChartLayoutId(ChartComponent location, [T? chartId]) {
    if (T == int || chartId == null) {
      chartId ??= 0 as T;
      return ChartLayoutId._(location, chartId as T);
    }
    return ChartLayoutId._(location, chartId);
  }

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

class RubinChart<C, I, A, T> extends StatefulWidget {
  final T chartId;
  final ChartInfo<C, I, A> info;
  final SelectionController<I>? selectionController;
  final Map<AxisId<A>, AxisController> axisControllers;

  const RubinChart({
    super.key,
    required this.info,
    T? chartId,
    this.selectionController,
    this.axisControllers = const {},
  }) : chartId = chartId ?? 0 as T;

  @override
  State<RubinChart<C, I, A, T>> createState() => RubinChartState<C, I, A, T>();
}

mixin RubinChartMixin<C, I, A, T> {
  List<Widget> buildSingleChartChildren(
    T chartId,
    ChartInfo<C, I, A> info,
    SelectionController<I>? selectionController,
    Map<AxisId<A>, AxisController> axisControllers,
  ) {
    List<Widget> children = [];
    Map<AxisId<A>, ChartAxisInfo<A>> axisInfo = info.axisInfo;

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
        children.add(
          LayoutId(
            id: ChartLayoutId(ChartComponent.legendFromLocation(info.legend!.location)!, chartId),
            child: VerticalLegendViewer(
              legend: info.legend!,
              theme: info.theme,
              seriesList: info.seriesList,
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

      children.add(
        LayoutId(
          id: ChartLayoutId(component, chartId),
          child: label,
        ),
      );
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

class RubinChartState<C, I, A, T> extends State<RubinChart<C, I, A, T>> with RubinChartMixin<C, I, A, T> {
  @override
  Widget build(BuildContext context) {
    return CustomMultiChildLayout(
      delegate: ChartLayoutDelegate(),
      children: buildSingleChartChildren(
        widget.chartId,
        widget.info,
        widget.selectionController,
        widget.axisControllers,
      ),
    );
  }
}

class ChartLayout<T> {
  final EdgeInsets margin;
  final Map<ChartLayoutId<T>, Offset> componentOffsets;
  final Map<ChartLayoutId<T>, Size> componentSizes;

  ChartLayout({
    required this.margin,
    required this.componentOffsets,
    required this.componentSizes,
  });
}

mixin ChartLayoutMixin<T> implements MultiChildLayoutDelegate {
  Map<T, ChartLayout<T>> componentLayouts = {};

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

  void layoutSingleChart(T chartId) {}
}

/// A delegate that lays out the components of a chart.
class ChartLayoutDelegate extends MultiChildLayoutDelegate with ChartLayoutMixin {
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

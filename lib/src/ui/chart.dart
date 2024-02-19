import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/series.dart';

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

/// Callback when an axis label is tapped.
typedef TapAxisCallback = void Function(int axisIndex);

/// Callback when an axis is updated (for example nby a zoom or pan gesture).
typedef AxisUpdateCallback = void Function(int axisIndex, ChartAxis axis);

/// A mixin that provides access to the series, axes, and legend of a chart.
/// This is made so that a state with a global key can have access to
/// its properties in other widgets.
mixin ChartMixin<T extends StatefulWidget, U> on State<T> {
  SeriesList get seriesList;
  Map<U, ChartAxes> get axes;
}

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
  chart,
}

/// A delegate that lays out the components of a chart.
class ChartLayoutDelegate extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {
    final Map<ChartComponent, Size> childSizes = {};

    for (ChartComponent component in ChartComponent.values) {
      if (hasChild(component) && component != ChartComponent.chart) {
        childSizes[component] = layoutChild(component, BoxConstraints.loose(size));
      }
    }

    List<ChartComponent> leftComponents = [
      ChartComponent.leftLegend,
      ChartComponent.leftAxis,
    ];

    List<ChartComponent> rightComponents = [
      ChartComponent.rightLegend,
      ChartComponent.rightAxis,
    ];

    List<ChartComponent> topComponents = [
      ChartComponent.title,
      ChartComponent.topLegend,
      ChartComponent.topAxis,
    ];

    List<ChartComponent> bottomComponents = [
      ChartComponent.bottomLegend,
      ChartComponent.bottomAxis,
    ];

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

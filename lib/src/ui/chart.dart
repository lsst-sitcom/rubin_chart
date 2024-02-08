import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/legend.dart';
import 'package:rubin_chart/src/models/series.dart';

/// Callback when sources are selected or deselected.
typedef SelectDatapointsCallback = void Function<T>(List<T> dataIds);

/// Callback when an axis label is tapped.
typedef TapAxisCallback = void Function(int axisIndex);

/// Callback when an axis is updated (for example nby a zoom or pan gesture).
typedef AxisUpdateCallback = void Function(int axisIndex, ChartAxis axis);

/// A mixin that provides access to the series, axes, and legend of a chart.
/// This is made so that a state with a global key can have access to
/// its properties in other widgets.
mixin ChartMixin<T extends StatefulWidget> on State<T> {
  List<Series> get seriesList;
  List<ChartAxis> get axes;
  Legend get legend;
}

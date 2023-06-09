import 'dart:math' as math;
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:rubin_chart/src/chart/axis.dart';
import 'package:rubin_chart/src/chart/projection.dart';
import 'package:rubin_chart/src/core/data.dart';
import 'package:rubin_chart/src/chart/legend.dart';
import 'package:rubin_chart/src/chart/marker.dart';
import 'package:rubin_chart/src/core/utils.dart';

import 'package:rubin_chart/src/core/workspace.dart';
import 'package:rubin_chart/src/chart/series.dart';
import 'package:rubin_chart/src/state/action.dart';
import 'package:rubin_chart/src/state/theme.dart';
import 'package:rubin_chart/src/state/workspace.dart';


/// Tools for selecting unique sources.
enum MultiSelectionTool {
  zoom(Icons.zoom_in),
  select(Icons.touch_app),
  drill(Icons.query_stats),
  pan(Icons.pan_tool);

  final IconData icon;
  const MultiSelectionTool(this.icon);
}


/// Select all points in a rectangular [region].
class RectSelectionAction extends WindowUpdate{
  /// The [Chart] that is being selected.
  final Chart chart;
  /// The rectangular region.
  final Rect region;
  /// The [Projection] used to map from axis coordinates to pixel coordinates.
  final Projection projection;
  /// The size of the plot area, in pixel coordinates.
  final Size plotSize;
  /// The [DataCenter] for the [Workspace].
  final DataCenter dataCenter;

  RectSelectionAction({
    required this.chart,
    required this.region,
    required this.projection,
    required this.plotSize,
    required this.dataCenter,
  });
}


/// Zoom into a a rectangular [region].
class RectZoomAction extends WindowUpdate{
  /// The [Chart] that is being selected.
  final Chart chart;
  /// The rectangular region.
  final Rect region;
  /// The [Projection] used to map from axis coordinates to pixel coordinates.
  final Projection projection;
  /// The size of the plot area, in pixel coordinates.
  final Size plotSize;

  RectZoomAction({
    required this.chart,
    required this.region,
    required this.projection,
    required this.plotSize,
  });
}


/// Remove a [Chart] from the [Workspace].
class RemoveChartAction extends UiAction {
  final Chart chart;
  const RemoveChartAction(this.chart);
}


/// Persistable information to generate a chart
abstract class Chart extends Window {
  final Map<int, Series> _series;
  final ChartLegend legend;
  final List<PlotAxis?> _axes;

  Chart({
    required super.id,
    required super.offset,
    required super.title,
    required super.size,
    required Map<int, Series> series,
    required List<PlotAxis?> axes,
    required this.legend,
  }): _series = Map.unmodifiable(series), _axes = List.unmodifiable(axes);

  /// Return a copy of the internal [Map] of [Series], to prevent updates.
  Map<int, Series> get series => {..._series};

  /// Return a copy of the internal [List] of [PlotAxis], to prevent updates.
  List<PlotAxis?> get axes => [..._axes];

  @override
  Chart copyWith({
    int? id,
    Offset? offset,
    Size? size,
    String? title,
    Map<int, Series>? series,
    List<PlotAxis?>? axes,
    ChartLegend? legend,
  });

  /// The names of all of the [DataSet]s that [Series] in this chart are connected to.
  Set<String> get dataSetNames {
    Set<String> result = {};
    for(Series series in _series.values){
      result.add(series.dataSetName);
    }
    return result;
  }

  /// Create a new [Widget] to display in a [WorkspaceViewer].
  @override
  Widget createWidget(BuildContext context) => RubinChart(chart: this);

  /// Create the internal chart, not including the [ChartLegend].
  Widget createInternalChart({
    required ChartTheme theme,
    required DataCenter dataCenter,
    required Size size,
    required WindowUpdateCallback dispatch,
  });

  /// Whether or not at least one [PlotAxis] has been set.
  bool get hasAxes => axes.isNotEmpty;

  /// Whether or not at least one [Series] has been initialized.
  bool get hasSeries => _series.isNotEmpty;

  /// Update [Chart] when [Series] is updated.
  Chart onSeriesUpdate({
    required Series series,
    required DataCenter dataCenter,
  }){
    Map<String, Bounds> bounds = dataCenter.getNumericalBounds(series);
    List<PlotAxis?> newAxes = [...axes];

    // Update the bounds for each unfixed axis
    for(int i=0; i<series.fields.length; i++){
      SchemaField field = series.fields[i];
      PlotAxis? axis = axes[i];

      if(axis == null){
        DataSet dataSet = dataCenter.dataSets[series.dataSetName]!;
        Bounds dataBounds = dataSet.getBounds(field.name);
        axis = PlotAxis.fromParameters(
          label: field.asLabel,
          bounds: dataBounds,
          orientation: i % 2 == 0
              ? AxisOrientation.horizontal
              : AxisOrientation.vertical,
        );
      } else {
        // Update the [PlotAxis] bounds
        Bounds newBounds = axis.bounds;
        if(newBounds.min == newBounds.max){
          newBounds == bounds[field.name];
        } else if(!axis.boundsFixed){
          newBounds = newBounds | bounds[field.name]!;
        }
        axis = axis.copyWith(bounds: newBounds);
      }
      newAxes[i] = axis;
    }
    return copyWith(axes: newAxes);
  }

  /// Check if a series is compatible with this chart.
  /// Any mismatched columns have their indices returned.
  List<int>? canAddSeries({
    required Series series,
    required DataCenter dataCenter,
  }){
    final List<int> mismatched = [];
    // Check that the series has the correct number of columns and axes
    if(series.fields.length != axes.length){
      developer.log("bad axes", name:"rubin_chart.core.chart.dart");
      return null;
    }
    for(int i =0; i<series.fields.length; i++){
      for(Series otherSeries in _series.values){
        // Check that the new series is compatible with the existing series
        if(!dataCenter.isFieldCompatible(otherSeries.fields[i], series.fields[i])){
          developer.log(
            "Incompatible fields ${otherSeries.fields[i]} and ${series.fields[i]}",
            name: "rubin_chart.core.chart.dart",
          );
          mismatched.add(i);
        }
      }
    }
    return mismatched;
  }

  /// Update [Chart] when [Series] is updated.
  Chart addSeries({
    required Series series,
    required DataCenter dataCenter,
  }){
    String name = series.name;
    // Always create new series with an index greater than all of the current series in the plot
    int index = (iterableMax(this.series.keys) ?? -1) + 1;
    // Create a default name
    if(name.isEmpty){
      name = "Series-$index";
    }
    series = series.copyWith(name: name, id: index);
    Map<int, Series> newSeries = {..._series};
    newSeries[series.id] = series;
    Chart result = copyWith(series: newSeries);
    return result.onSeriesUpdate(series: series, dataCenter: dataCenter);
  }

  /// Create a new empty Series for this [Chart].
  Series nextSeries({required DataCenter dataCenter});

  int get nMaxAxes;

  MarkerSettings getMarkerSettings({
    required Series series,
    required ChartTheme theme,
  }){
    if(series.marker != null){
      // The user specified a marker for this [Series], so use it.
      return series.marker!;
    }
    // The user did not specify a marker, so use the default marker with the color updated
    return MarkerSettings(
      color: theme.getMarkerColor(_series.keys.toList().indexOf(series.id)),
      edgeColor: theme.getMarkerEdgeColor(_series.keys.toList().indexOf(series.id)),
    );
  }

  @override
  Widget? createToolbar(BuildContext context){
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: (){
          workspace.dispatch(RemoveChartAction(this));
        },
      ),
    );
  }

  Map<String, Set<dynamic>> selectRegion({
    required RectSelectionAction action,
  });

  List<PlotAxis?> axesZoom({
    required RectZoomAction action,
  });
}


/// A chart containing a legend.
class RubinChart extends StatelessWidget {
  final Chart chart;

  const RubinChart({
    super.key,
    required this.chart,
  });

  @override
  Widget build(BuildContext context){
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    DataCenter dataCenter = workspace.dataCenter;

    Size size = chart.size;

    ChartLegend legend = chart.legend;
    if(legend.location == ChartLegendLocation.right){
      return SizedBox(
        height: size.height,
        width: size.width,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
                child: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints){
                  return chart.createInternalChart(
                    theme: workspace.theme,
                    dataCenter: dataCenter,
                    size: Size(
                      constraints.maxWidth,
                      size.height,
                    ),
                    dispatch: workspace.dispatch,
                  );
                })
            ),
            VerticalChartLegendViewer(
              theme: workspace.theme,
              chart: chart,
            ),
          ],
        ),
      );
    }
    throw UnimplementedError("ChartLegendLocation ${chart.legend.location} not yet supported");
  }

  /// Implement the [RubinChart.of] method to allow children
  /// to find this container based on their [BuildContext].
  static RubinChart of(BuildContext context){
    final RubinChart? result = context.findAncestorWidgetOfExactType<RubinChart>();
    assert((){
      if (result == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
              'RubinChart.of() called with a context that does not '
                  'contain a RubinChart.'
          ),
          ErrorDescription(
              'No RubinChart ancestor could be found starting from the context '
                  'that was passed to RubinChart.of().'
          ),
          ErrorHint(
              'This probably happened when an interactive child was created '
                  'outside of a RubinChart'
          ),
          context.describeElement('The context used was')
        ]);
      }
      return true;
    }());
    return result!;
  }
}

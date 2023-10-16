import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:rubin_chart/src/chart/axis.dart';
import 'package:rubin_chart/src/chart/chart.dart';
import 'package:rubin_chart/src/chart/legend.dart';
import 'package:rubin_chart/src/chart/series.dart';
import 'package:rubin_chart/src/charts/cartesian.dart';
import 'package:rubin_chart/src/charts/scatter.dart';
import 'package:rubin_chart/src/core/data.dart';
import 'package:rubin_chart/src/core/menu.dart';
import 'package:rubin_chart/src/core/toolbar.dart';
import 'package:rubin_chart/src/core/workspace.dart';
import 'package:rubin_chart/src/query/query.dart';
import 'package:rubin_chart/src/state/action.dart';
import 'package:rubin_chart/src/state/theme.dart';
import 'package:rubin_chart/src/state/time_machine.dart';


/// Auto counter to keep track of the next window ID.
int _nextWindowId = 0;


/// A single, persistable, item displayed in a [Workspace].
abstract class Window {
  /// The [id] of this [Window] in [Workspace.windows].
  final int id;
  /// The location of the entry in the entire workspace
  final Offset offset;
  /// The size of the entry in the entire workspace
  final Size size;
  /// The title to display in the window bar.
  final String? title;

  const Window({
    required this.id,
    required this.offset,
    required this.size,
    this.title,
  });

  Window copyWith({
    int? id,
    Offset? offset,
    Size? size,
    String? title,
  });

  /// Create a new [Widget] to display in a [Workspace].
  Widget createWidget(BuildContext context);

  Widget? createToolbar(BuildContext context);
}


/// The full working area of the app.
class Workspace {
  /// Windows to display in the [Workspace].
  final Map<int, Window> _windows;
  /// The theme for the app
  final ChartTheme theme;
  /// Keys for selected data points.
  /// The key is name of the [DataSet] containing the point, and the [Set] is the
  /// set of keys in that [DataSet] that are selected.
  final Map<String, Set<dynamic>> _selected;
  /// Which tool to use for multi-selection/zoom
  final MultiSelectionTool multiSelectionTool;

  const Workspace({
    required this.theme,
    Map<int, Window> windows = const {},
    Map<String, Set<dynamic>> selected = const {},
    this.multiSelectionTool = MultiSelectionTool.select,
  }):_windows = windows, _selected = selected;

  Workspace copyWith({
    ChartTheme? theme,
    Map<int, Window>? windows,
    Map<String, Set<dynamic>>? selected,
    MultiSelectionTool? multiSelectionTool,
  }) => Workspace(
    theme: theme ?? this.theme,
    windows: windows ?? this.windows,
    selected: selected ?? this.selected,
    multiSelectionTool: multiSelectionTool ?? this.multiSelectionTool,
  );

  /// Protect [_windows] so that it can only be updated through the app.
  Map<int, Window> get windows => {..._windows};

  /// Protect [_selected] so that it can only be updated through the app.
  Map<String, Set<dynamic>> get selected => {..._selected};

  /// Add a new [Window] to the [WorkspaceWidgetState].
  /// Normally the [index] is already created, unless
  /// the workspace is being loaded from disk.
  Workspace addWindow(Window window){
    Map<int, Window> newWindows = {..._windows};

    if(window.id < 0){
      // Use the next entry counter to increment the index
      int index = _nextWindowId++;
      window = window.copyWith(id: index);
    } else if(window.id > _nextWindowId){
      // The new entry is greater than the next entry counter, so make the new next entry
      // greater than the current index
      _nextWindowId = window.id + 1;
    }
    newWindows[window.id] = window;

    return copyWith(
      windows: newWindows,
    );
  }
}


/// Add a new cartesian plot to the workspace
TimeMachine<Workspace> newCartesianPlotReducer(
    TimeMachine<Workspace> state,
    NewCartesianPlotAction action,
){
  Workspace workspace = state.currentState;
  Offset offset = workspace.theme.newWindowOffset;

  if(workspace.windows.isNotEmpty){
    // Shift from last window
    offset += workspace.windows.values.last.offset;
  }

  int id = -1;
  for(int key in workspace.windows.keys){
    if(key > id){
      id = key;
    }
  }

  workspace = workspace.addWindow(CartesianPlot(
    id: ++id,
    offset: offset,
    size: workspace.theme.newPlotSize,
    series: {},
    axes: [null, null],
    legend: ChartLegend(location: ChartLegendLocation.right),
  ));

  return state.updated(TimeMachineUpdate(
    comment: "add new Cartesian plot",
    state: workspace,
  ));
}


/// Add a new cartesian plot to the workspace
TimeMachine<Workspace> updateSeriesReducer(
    TimeMachine<Workspace> state,
    SeriesUpdateAction action,
){
  Chart chart = action.chart;
  late String comment = "update Series";

  if(action.groupByColumn != null){
    // Create a collection of series grouped by the specified column
    DataSet dataSet = action.dataCenter.dataSets[action.series.dataSetName]!;
    SchemaField field = dataSet.schema.fields[action.groupByColumn!]!;

    Set indices = dataSet.getValid(action.series);
    Set unique = {};
    for(dynamic index in indices){
      Map<String, dynamic> record = dataSet.data[index]!;
      unique.add(record[field.name]);
    }

    developer.log("Creating ${unique.length} new series", name: "rubin_chart.workspace");

    for(dynamic value in unique){
      Series series = action.series;

      Query groupQuery = EqualityQuery(
        columnField: field,
        rightCondition: EqualityCondition(
          operator: EqualityOperator.eq,
          value: value,
        ),
      );

      Query query = groupQuery;

      if(series.query != null){
        query = ParentQuery(
          children: [series.query!, groupQuery],
          operator: QueryOperator.and,
        );
      }
      series = series.copyWith(name: value, query: query);
      chart = chart.addSeries(series: series, dataCenter: action.dataCenter);
    }
  } else if(chart.series.keys.contains(action.series.id)){
    Map<int, Series> newSeries = {...chart.series};
    newSeries[action.series.id] = action.series;
    chart = chart.copyWith(series: newSeries);
    chart = chart.onSeriesUpdate(series: action.series, dataCenter: action.dataCenter);
  } else {
    chart = chart.addSeries(series: action.series, dataCenter: action.dataCenter);
    comment = "add new Series";
  }

  Workspace workspace = state.currentState;
  Map<int, Window> windows = {...workspace.windows};
  windows[chart.id] = chart;

  return state.updated(TimeMachineUpdate(
    comment: comment,
    state: workspace.copyWith(windows: windows),
  ));
}


/// Add a new cartesian plot to the workspace
TimeMachine<Workspace> updateAxisReducer(
    TimeMachine<Workspace> state,
    AxisUpdate action,
){
  Workspace workspace = state.currentState;
  List<PlotAxis?> newAxes = [...action.chart.axes];
  newAxes[action.axisIndex] = action.newAxis;
  Chart chart = action.chart.copyWith(axes: newAxes);
  Map<int, Window> windows = {...workspace.windows};
  windows[chart.id] = chart;
  workspace = workspace.copyWith(windows: windows);

  return state.updated(TimeMachineUpdate(
    comment: "update PlotAxis",
    state: workspace,
  ));
}


/// Add a new cartesian plot to the workspace
TimeMachine<Workspace> rectSelectionReducer(
    TimeMachine<Workspace> state,
    RectSelectionAction action,
){
  Workspace workspace = state.currentState;

  Map<String, Set<dynamic>> selected = action.chart.selectRegion(action: action);
  workspace = workspace.copyWith(selected: selected);

  return state.updated(TimeMachineUpdate(
    comment: "select points in Rect",
    state: workspace,
  ));
}


/// Add a new cartesian plot to the workspace
TimeMachine<Workspace> pointSelectionReducer(
    TimeMachine<Workspace> state,
    PointSelectionAction action,
){
  Workspace workspace = state.currentState;
  String comment = "select points";
  if(action.dataSetName == null){
    workspace = workspace.copyWith(selected: {});
    comment = "clear selected points";
  } else {
    workspace = workspace.copyWith(selected: {action.dataSetName!: action.selected!});
  }

  return state.updated(TimeMachineUpdate(
    comment: comment,
    state: workspace,
  ));
}


/// Add a new cartesian plot to the workspace
TimeMachine<Workspace> rectZoomReducer(
    TimeMachine<Workspace> state,
    RectZoomAction action,
){
  Workspace workspace = state.currentState;
  List<PlotAxis?> newAxes = action.chart.axesZoom(action: action);
  Chart chart = action.chart.copyWith(axes: newAxes);
  Map<int, Window> windows = {...workspace.windows};
  windows[chart.id] = chart;
  workspace = workspace.copyWith(windows: windows);

  return state.updated(TimeMachineUpdate(
    comment: "rect zoom into PlotAxis",
    state: workspace,
  ));
}


/// Add a new cartesian plot to the workspace
TimeMachine<Workspace> updateWindowReducer(
    TimeMachine<Workspace> state,
    ApplyWindowUpdate action,
){
  Workspace workspace = state.currentState;
  Map<int, Window> windows = {...workspace.windows};
  Window window = windows[action.windowId]!.copyWith(offset: action.offset, size: action.size);
  windows[window.id] = window;
  workspace = workspace.copyWith(windows: windows);

  return state.updated(TimeMachineUpdate(
    comment: "update a window size and position",
    state: workspace,
  ));
}


/// Add a new cartesian plot to the workspace
TimeMachine<Workspace> removeChartReducer(
    TimeMachine<Workspace> state,
    RemoveChartAction action,
){
  Workspace workspace = state.currentState;
  Map<int, Window> windows = {...workspace.windows};
  windows.remove(action.chart.id);
  workspace = workspace.copyWith(windows: windows);

  return state.updated(TimeMachineUpdate(
    comment: "remove chart",
    state: workspace,
  ));
}


/// Add a new cartesian plot to the workspace
TimeMachine<Workspace> updateMultiSelectReducer(
    TimeMachine<Workspace> state,
    UpdateMultiSelect action,
    ){
  Workspace workspace = state.currentState;
  return state.updated(TimeMachineUpdate(
    comment: "change selection tool",
    state: workspace.copyWith(multiSelectionTool: action.tool),
  ));
}


/// Reduce a [TimeMachineAction] and (potentially) update the history and workspace.
TimeMachine<Workspace> timeMachineReducer(TimeMachine<Workspace> state, TimeMachineAction action){
  if(action.action == TimeMachineActions.first){
    return state.first;
  } else if(action.action == TimeMachineActions.previous){
    return state.previous;
  } else if(action.action == TimeMachineActions.next){
    return state.next;
  } else if(action.action == TimeMachineActions.last){
    return state.last;
  }
  return state;
}


/// Handle a workspace action
Reducer<TimeMachine<Workspace>> workspaceReducer = combineReducers<TimeMachine<Workspace>>([
  TypedReducer<TimeMachine<Workspace>, TimeMachineAction>(timeMachineReducer),
  TypedReducer<TimeMachine<Workspace>, NewCartesianPlotAction>(newCartesianPlotReducer),
  TypedReducer<TimeMachine<Workspace>, SeriesUpdateAction>(updateSeriesReducer),
  TypedReducer<TimeMachine<Workspace>, AxisUpdate>(updateAxisReducer),
  TypedReducer<TimeMachine<Workspace>, RectSelectionAction>(rectSelectionReducer),
  TypedReducer<TimeMachine<Workspace>, PointSelectionAction>(pointSelectionReducer),
  TypedReducer<TimeMachine<Workspace>, RectZoomAction>(rectZoomReducer),
  TypedReducer<TimeMachine<Workspace>, ApplyWindowUpdate>(updateWindowReducer),
  TypedReducer<TimeMachine<Workspace>, RemoveChartAction>(removeChartReducer),
TypedReducer<TimeMachine<Workspace>, UpdateMultiSelect>(updateMultiSelectReducer),
]);

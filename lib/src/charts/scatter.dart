import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rubin_chart/src/chart/axis.dart';
import 'package:rubin_chart/src/chart/chart.dart';
import 'package:rubin_chart/src/core/data.dart';
import 'package:rubin_chart/src/chart/legend.dart';
import 'package:rubin_chart/src/chart/marker.dart';
import 'package:rubin_chart/src/chart/projection.dart';
import 'package:rubin_chart/src/core/utils.dart';
import 'package:rubin_chart/src/chart/series.dart';
import 'package:rubin_chart/src/core/workspace.dart';
import 'package:rubin_chart/src/state/action.dart';
import 'package:rubin_chart/src/state/theme.dart';


class PointSelectionAction extends UiAction {
  String? dataSetName;
  Set<dynamic>? selected;

  PointSelectionAction({
    required this.dataSetName,
    required this.selected,
  });
}


class MultiSelectEndDetails {
  final DragEndDetails details;
  final Size plotSize;
  final DataCenter dataCenter;
  final MultiSelectionTool multiSelectionTool;
  final DispatchAction dispatch;

  const MultiSelectEndDetails({
    required this.details,
    required this.plotSize,
    required this.dataCenter,
    required this.multiSelectionTool,
    required this.dispatch,
  });
}


mixin PlotState<T extends StatefulWidget> on State<T> {
  Chart get chart;

  ChartTheme get theme;

  int _nextSeries = 0;

  bool dataLoaded = false;

  late Projection2D currentProjection;

  Offset? panInitialLocalOffset;
  Offset? panInitialOffset;
  Offset? panOffset;
  OverlayEntry? highlighter;

  /// Edit an axis
  Future<PlotAxis?> editAxis({
    required BuildContext context,
    required PlotAxis? axis,
    required String title,
    required int axisIndex,
    required AxisOrientation orientation,
    required Bounds dataBounds,
  }) async {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    return showDialog<PlotAxis?>(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: AxisEditor(
          title: title,
          theme: theme,
          axis: axis,
          info: chart,
          axisIndex: axisIndex,
          orientation: orientation,
          dataBounds: dataBounds,
          dispatch: workspace.dispatch,
          dataCenter: workspace.dataCenter,
        ),
      ),
    );
  }

  void addSeries({
    required Series series,
    bool resizeAxes = true,
  }){
    series = series.copyWith(
      id: _nextSeries++,
    );

    setState(() {});
  }

  ChartLegend? legend;

  Widget? getMarker({
    required Projection2D projection,
    required Series series,
    required dynamic key,
    required dynamic dataPoint,
    required List<PlotAxis> axes,
    required DispatchAction dispatch,
    bool isSelection = false,
  }){
    String xColumnName = series.fields[0].name;
    String yColumnName = series.fields[1].name;
    MarkerSettings marker = chart.getMarkerSettings(series: series, theme: theme);

    if(dataPoint[xColumnName] != null && dataPoint[yColumnName]!= null){
      double markerRadius = marker.size / 2;
      if(isSelection){
        markerRadius *= 1.5;
      }
      double x = dataPoint[xColumnName].toDouble();
      double y = dataPoint[yColumnName].toDouble();

      math.Point point = projection.project(
        coordinates:[x, y],
        axes: [axes[0], axes[1]],
      );

      return Positioned(
        left: point.x-markerRadius,
        bottom: point.y-markerRadius,
        child: GestureDetector(
          onTap: (){
            dispatch(PointSelectionAction(
              dataSetName: series.dataSetName,
              selected: {key},
            ));
          },
          child: Marker(
            size: isSelection ? marker.size * 1.5 : marker.size,
            color: isSelection ? theme.selectionColor : marker.color,
            edgeColor: isSelection ? theme.selectionEdgeColor : marker.edgeColor,
            markerType: marker.type,
          ),
        ),
      );
    }
    return null;
  }

  List<Widget> getMarkers({
    required Projection2D projection,
    required Size plotSize,
    required List<PlotAxis> axes,
    required DispatchAction dispatch,
    required DataCenter dataCenter,
  }){
    List<Widget> result = [];

    for(Series series in chart.series.values){
      if(dataCenter.dataSets.keys.contains(series.dataSetName)){
        DataSet dataSet = dataCenter.dataSets[series.dataSetName]!;
        final Set indices = {};
        if(series.query != null){
          indices.addAll(series.query!.getIndices(dataSet: dataSet));
        }

        for(MapEntry<dynamic, dynamic> entry in dataSet.data.entries){
          if(series.query == null || indices.contains(entry.key)){
            Widget? marker = getMarker(
              projection: projection,
              series: series,
              key: entry.key,
              dataPoint: entry.value,
              axes: axes,
              dispatch: dispatch,
            );

            if(marker != null){
              result.add(marker);
            }
          }
        }
      } else {
        // The dataset has not been loaded yet, so skip this series
      }
    }
    return result;
  }

  List<Widget> getSelectedMarkers({
    required Projection2D projection,
    required Size plotSize,
    required List<PlotAxis> axes,
    required DispatchAction dispatch,
    required Map<String, Set<dynamic>> selected,
    required DataCenter dataCenter,
  }){
    List<Widget> result = [];

    for(MapEntry entry in selected.entries){
      String dataSetName = entry.key;
      Set<dynamic> keys = entry.value;

      for(Series series in chart.series.values){
        if(dataSetName == series.dataSetName){
          DataSet dataSet = dataCenter.dataSets[series.dataSetName]!;
          for(dynamic dataKey in keys){
            dynamic dataPoint = dataSet.data[dataKey];
            Widget? marker = getMarker(
              projection: projection,
              series: series,
              key: dataKey,
              dataPoint: dataPoint,
              isSelection: true,
              axes: axes,
              dispatch: dispatch,
            );
            if(marker != null){
              result.add(marker);
            }
          }
        } else {
          // The dataset has not been loaded yet, so skip this series
        }
      }
    }
    return result;
  }

  onPanStart(DragStartDetails details){
    panInitialOffset = details.globalPosition;
    panInitialLocalOffset = details.localPosition;
    panOffset = details.globalPosition;
    highlighter = OverlayEntry(builder: (BuildContext context){
      double left = math.min(panOffset!.dx, panInitialOffset!.dx);
      double right = math.max(panOffset!.dx, panInitialOffset!.dx);
      double top = math.min(panOffset!.dy, panInitialOffset!.dy);
      double bottom = math.max(panOffset!.dy, panInitialOffset!.dy);

      Widget highlighter = Container(
        width: right - left,
        height: bottom - top,
        decoration: const BoxDecoration(
          color: Color(0x22222222),
        ),
      );
      return Positioned(
        left: left,
        top: top,
        child: highlighter,
      );
    });
    final OverlayState overlay = Overlay.of(context);
    overlay.insert(highlighter!);
    setState(() {});
  }

  onPanUpdate(DragUpdateDetails details){
    panOffset = details.globalPosition;
    highlighter!.markNeedsBuild();
    setState(() {});
  }

  onPanEnd(MultiSelectEndDetails details){
    Offset positionOffset = panInitialOffset! - panInitialLocalOffset!;
    double xOffset = positionOffset.dx;
    double yOffset = positionOffset.dy;
    double left = math.min(panOffset!.dx, panInitialOffset!.dx) - xOffset;
    double right = math.max(panOffset!.dx, panInitialOffset!.dx) - xOffset;
    double top = math.min(panOffset!.dy, panInitialOffset!.dy) - yOffset;
    double bottom = math.max(panOffset!.dy, panInitialOffset!.dy) - yOffset;

    if(details.multiSelectionTool == MultiSelectionTool.select){
      details.dispatch(RectSelectionAction(
        chart: chart,
        region: Rect.fromLTRB(left, top, right, bottom),
        projection: currentProjection,
        plotSize: details.plotSize,
        dataCenter: details.dataCenter,
      ));
    } else if(details.multiSelectionTool == MultiSelectionTool.zoom){
      details.dispatch(RectZoomAction(
        chart: chart,
        region: Rect.fromLTRB(left, top, right, bottom),
        projection: currentProjection,
        plotSize: details.plotSize,
      ));
    }

    highlighter?.remove();
    panOffset = null;
    panInitialOffset = null;
    panInitialLocalOffset = null;
    setState(() {});
  }
}

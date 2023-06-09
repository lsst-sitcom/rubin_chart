import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rubin_chart/src/chart/axis.dart';
import 'package:rubin_chart/src/chart/chart.dart';
import 'package:rubin_chart/src/chart/legend.dart';
import 'package:rubin_chart/src/charts/scatter.dart';
import 'package:rubin_chart/src/core/data.dart';
import 'package:rubin_chart/src/chart/projection.dart';
import 'package:rubin_chart/src/core/utils.dart';
import 'package:rubin_chart/src/core/workspace.dart';
import 'package:rubin_chart/src/chart/series.dart';
import 'package:rubin_chart/src/state/theme.dart';


class CartesianPlot extends Chart {
  CartesianPlot({
    required super.id,
    required super.offset,
    required super.size,
    super.title = "untitled",
    required super.series,
    required super.axes,
    required super.legend,
  });

  @override
  CartesianPlot copyWith({
    int? id,
    Offset? offset,
    Size? size,
    String? title,
    Map<int, Series>? series,
    List<PlotAxis?>? axes,
    ChartLegend? legend,
  }) => CartesianPlot(
    id: id ?? this.id,
    offset: offset ?? this.offset,
    title: title ?? this.title,
    size: size ?? this.size,
    series: series ?? this.series,
    axes: axes ?? this.axes,
    legend: legend ?? this.legend,
  );

  /// Create a new [Widget] to display in a [WorkspaceViewer].
  @override
  Widget createInternalChart({
    required ChartTheme theme,
    required DataCenter dataCenter,
    required Size size,
    required WindowUpdateCallback dispatch,
  }) => CartesianPlotViewer(
    theme: theme,
    chart: this,
    dataCenter: dataCenter,
    size: size,
    dispatch: dispatch,
  );

  PlotAxis? get xAxis1 => axes[0];
  PlotAxis? get yAxis1 => axes[1];
  PlotAxis? get xAxis2 => axes.length > 2 ? axes[2] : null;
  PlotAxis? get yAxis2 => axes.length > 2 ? axes[3] : null;

  bool get has2ndAxes => axes.length == 4;

  @override
  int get nMaxAxes => 4;

  @override
  Series nextSeries({required DataCenter dataCenter}){
    DataSet dataSet = dataCenter.dataSets.values.first;

    // Always create new series with an index greater than all of the current series in the plot
    int index = (iterableMax(this.series.keys) ?? -1) + 1;

    Series series = Series(
      id: index,
      name: "Series-$index",
      fields: [
        dataSet.schema.fields.values.first,
        dataSet.schema.fields.values.skip(1).first,
      ],
      dataSetName: dataSet.name,
    );
    return series;
  }

  @override
  Map<String, Set<dynamic>> selectRegion({
    required RectSelectionAction action,
  }){
    Chart chart = action.chart;
    Map<String, Set<dynamic>> keys = {};

    for(Series series in chart.series.values){
      DataSet dataSet = action.dataCenter.dataSets[series.dataSetName]!;
      Set validKeys = dataSet.getValid(series);

      keys[dataSet.name] = {};

      for(dynamic key in validKeys){
        dynamic record = dataSet.data[key];
        double x = record[series.fields[0].name].toDouble();
        double y = record[series.fields[1].name].toDouble();
        math.Point point = action.projection.project(
          coordinates: <double>[x, y],
          axes: [axes[0]!, axes[1]!],
        );
        Offset offset = Offset(point.x.toDouble(), action.plotSize.height-point.y.toDouble());
        if(action.region.contains(offset)){
          //print("adding source at $x, $y at ${point.x}, ${point.y} ");
          keys[dataSet.name]!.add(key);
        }
      }
    }
    return keys;
    
  }

  @override
  List<PlotAxis?> axesZoom({
    required RectZoomAction action,
  }){
    double x1 = action.projection.xTransform.inverse(action.region.left);
    double x2 = action.projection.xTransform.inverse(action.region.right);
    double y1 = action.projection.yTransform.inverse(action.plotSize.height - action.region.top);
    double y2 = action.projection.yTransform.inverse(action.plotSize.height - action.region.bottom);
    double xMin = math.min(x1, x2);
    double xMax = math.max(x1, x2);
    double yMin = math.min(y1, y2);
    double yMax = math.max(y1, y2);

    List<PlotAxis?> newAxes = [...axes];

    newAxes[0] = axes[0]!.copyWith(bounds: Bounds(xMin, xMax));
    newAxes[1] = axes[1]!.copyWith(bounds: Bounds(yMin, yMax));
    return newAxes;
  }
}


class CartesianPlotViewer extends StatefulWidget {
  final ChartTheme theme;
  final CartesianPlot chart;
  final DataCenter dataCenter;
  final Size size;
  final WindowUpdateCallback dispatch;

  const CartesianPlotViewer({
    super.key,
    required this.theme,
    required this.chart,
    required this.dataCenter,
    required this.size,
    required this.dispatch,
  });

  @override
  CartesianPlotViewerState createState() => CartesianPlotViewerState();
}


class CartesianPlotViewerState extends State<CartesianPlotViewer> with PlotState{
  final PlotAxis _defaultXAxis = PlotAxis.fromParameters(
    label: "x (unit)",
    orientation: AxisOrientation.horizontal,
    bounds: const Bounds(0, 1),
  );

  final PlotAxis _defaultYAxis = PlotAxis.fromParameters(
    label: "y (unit)",
    orientation: AxisOrientation.vertical,
    bounds: const Bounds(0, 1),
  );

  PlotAxis get xAxis1 => chart.xAxis1 ?? _defaultXAxis;
  PlotAxis get yAxis1 => chart.yAxis1 ?? _defaultYAxis;
  PlotAxis? get xAxis2 => chart.xAxis2;
  PlotAxis? get yAxis2 => chart.yAxis2;

  @override
  CartesianPlot get chart => widget.chart;

  Size get size => widget.size;

  @override
  ChartTheme get theme => widget.theme;

  String? get title => chart.title;

  Bounds getDataBounds(int i, DataCenter dataCenter){
    Series series = chart.series.values.first;
    DataSet dataSet = dataCenter.dataSets[series.dataSetName]!;
    return dataSet.getBounds(series.fields[i].name);
  }

  @override
  Widget build(BuildContext context){
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    DataCenter dataCenter = workspace.dataCenter;

    // TODO: only calculate these if the axes have changed
    double xAxisHeight = math.max(
      HorizontalAxisWidget.getHeight(theme: theme, axis: xAxis1),
      kMinInteractiveDimension,
    );

    double yAxisWidth = math.max(
      VerticalAxisWidget.getWidth(theme: theme, axis: yAxis1),
      kMinInteractiveDimension,
    );

    Size plotSize = Size(
      size.width - xAxisHeight,
      size.height - xAxisHeight,
    );

    /*print("Size is $size, plotSize is $plotSize");
    print("x bounds: ${xAxis.bounds}, y bounds: ${yAxis.bounds}");

    if(xAxis.majorTicks != null){
      print(xAxis.majorTicks!.ticks);
      print(xAxis.majorTicks!.labels);
    }
    if(yAxis.majorTicks != null){
      print(yAxis.majorTicks!.ticks);
      print(yAxis.majorTicks!.labels);
    }*/

    // Get the transforms to from axis coordinates to pixel coordinates
    PlotTransform? xTransform;
    PlotTransform? yTransform;

    xTransform = PlotTransform.fromAxis(
      axis: xAxis1,
      plotSize: plotSize.width,
      invertSize: xAxis1.isInverted ? plotSize.width : null,
    );

    yTransform = PlotTransform.fromAxis(
      axis: yAxis1,
      plotSize: plotSize.height,
      invertSize: yAxis1.isInverted ? plotSize.height : null,
    );

    //print("$xTransform\n$yTransform");

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          color: theme.themeData.colorScheme.background,
        ),
        child: Stack(
          children: [
            // The y-axis
            Positioned(
                top: 0,
                left: 0,
                child: GestureDetector(
                  onTap: (){
                    if(chart.series.isNotEmpty){
                      editAxis(
                        context: context,
                        axis: chart.yAxis1,
                        title: "y-axis",
                        axisIndex: 1,
                        orientation: AxisOrientation.vertical,
                        dataBounds: getDataBounds(1, dataCenter),
                      );
                    }
                  },
                  child: VerticalAxisWidget(
                    theme: theme,
                    axis: yAxis1,
                    size: Size(yAxisWidth, size.height),
                    transform: yTransform,
                    plotOffset: xAxisHeight,
                  )
                ),
            ),

            // The x-axis
            Positioned(
                bottom: 0,
                left: 0,
                child: GestureDetector(
                  onTap: (){
                    if(chart.series.isNotEmpty){
                      editAxis(
                        context: context,
                        axis: chart.xAxis1,
                        title: "x-axis",
                        axisIndex: 0,
                        orientation: AxisOrientation.horizontal,
                        dataBounds: getDataBounds(0, dataCenter),
                      );
                    }
                  },
                  child: HorizontalAxisWidget(
                    theme: theme,
                    axis: xAxis1,
                    size: Size(size.width, xAxisHeight),
                    transform: xTransform,
                    plotOffset: yAxisWidth,
                  )
                ),
            ),

            // The main plot area
            Positioned(
              top: 0,
              left: size.width - plotSize.width,
              child: GestureDetector(
                onTap: (){
                  workspace.dispatch(PointSelectionAction(dataSetName: null, selected: null));
                },
                onPanStart: onPanStart,
                onPanUpdate: onPanUpdate,
                onPanEnd: (DragEndDetails details){
                  onPanEnd(MultiSelectEndDetails(
                    details: details,
                    plotSize: plotSize,
                    dataCenter: dataCenter,
                    multiSelectionTool: workspace.widget.workspace.multiSelectionTool,
                    dispatch: workspace.dispatch,
                  ));
                },
                child: Container(
                    width: plotSize.width,
                    height: plotSize.height,
                    decoration: BoxDecoration(
                      color: theme.themeData.colorScheme.background,
                      border: Border(
                        left: BorderSide(width: theme.majorTickWidth, color: theme.axisColor),
                        bottom: BorderSide(width: theme.majorTickWidth, color: theme.axisColor),
                      ),
                    ),
                    child: Builder(
                        builder: (BuildContext context){
                          final List<Widget> children = [];

                          currentProjection = Linear2DProjection.fromAxes(
                            xAxis: xAxis1,
                            yAxis: yAxis1,
                            plotSize: plotSize,
                          );

                          children.addAll(getMarkers(
                            projection: currentProjection,
                            plotSize: plotSize,
                            axes: [yAxis1, yAxis1],
                            dataCenter: dataCenter,
                            dispatch: workspace.dispatch,
                          ));

                          children.addAll(getSelectedMarkers(
                            projection: currentProjection,
                            plotSize: plotSize,
                            axes: [xAxis1, yAxis1],
                            dataCenter: dataCenter,
                            dispatch: workspace.dispatch,
                            selected: workspace.selected,
                          ));
                          return Stack(
                            children: children,
                          );
                        }
                    )
                )
              ),
            ),
          ],
        ),
      )
    );
  }
}

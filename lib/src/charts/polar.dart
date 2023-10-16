import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:rubin_chart/src/chart/axis.dart';
import 'package:rubin_chart/src/chart/chart.dart';
import 'package:rubin_chart/src/core/data.dart';
import 'package:rubin_chart/src/chart/legend.dart';
import 'package:rubin_chart/src/chart/projection.dart';
import 'package:rubin_chart/src/core/workspace.dart';
import 'package:rubin_chart/src/chart/series.dart';
import 'package:rubin_chart/src/state/theme.dart';
import 'package:rubin_chart/src/core/utils.dart';


/*class PolarPlotInfo extends ChartInfo {
  PolarPlotInfo({
    required super.offset,
    required super.size,
    super.title = "untitled",
    required super.series,
    required super.axes,
    super.legend,
  });

  /// Create a new [Widget] to display in a [Workspace].
  @override
  Widget createInternalChart({
    required ChartTheme theme,
    required DataCenter dataCenter,
    required Size size,
    required WindowUpdateCallback dispatch,
  }) => PolarPlot(
    theme: theme,
    info: this,
    dataCenter: dataCenter,
    size: size,
    dispatch: dispatch,
  );
}


class PolarPlot extends StatefulWidget {
  final ChartTheme theme;
  final ChartInfo info;
  final DataCenter dataCenter;
  final Size size;
  final WindowUpdateCallback dispatch;

  const PolarPlot({
    super.key,
    required this.theme,
    required this.info,
    required this.dataCenter,
    required this.size,
    required this.dispatch,
  });

  @override
  PolarPlotState createState() => PolarPlotState();
}


class PolarPlotState extends State<PolarPlot> with PlotState{
  @override
  WindowUpdateCallback get dispatch => widget.dispatch;

  PlotAxis get rAxis => info.axes.isNotEmpty ? info.xAxis1 : _defaultXAxis;
  PlotAxis get thetaAxis => info.axes.isNotEmpty ? info.yAxis1 : _defaultYAxis;

  @override
  void initState(){
    super.initState();
    // Set the various properties to initialize the size of their child widgets
    SchemaField rField = const SchemaField(
      name: "r",
      dataType: DataTypes.integer,
      unit: "unit",
    );
    SchemaField thetaField = const SchemaField(
      name: "\u0238",
      dataType: DataTypes.integer,
      unit: "deg",
    );
    rAxis = PlotAxis(field: rField, orientation: AxisOrientation.radial);
    thetaAxis = PlotAxis(field: thetaField, orientation: AxisOrientation.angular);
    dataCenter.controller.stream.asBroadcastStream().listen(onDataUpdate);
  }

  @override
  void updateSeriesData(Series series){
    if(series.useInAxes){
      Map<String, Bounds> bounds = dataCenter.getNumericalBounds(series);
      DataSet dataSet = dataCenter.dataSets[series.dataSetName]!;
      SchemaField rField = dataSet.schema.fields[series.columnNames[0]]!;
      SchemaField thetaField = dataSet.schema.fields[series.columnNames[1]]!;

      if((!rAxis.boundsFixed || rAxis.bounds == null)){
        rAxis.addSeries(field: rField, seriesBounds: bounds[series.columnNames[0]]!);
      }
      if((!thetaAxis.boundsFixed || thetaAxis.bounds == null)){
        thetaAxis.addSeries(field: thetaField, seriesBounds: bounds[series.columnNames[1]]!);
      }
    }
  }

  @override
  PolarPlotInfo get info => widget.info as PolarPlotInfo;

  Size get size => widget.info.size!;

  @override
  DataCenter get dataCenter => widget.dataCenter;

  @override
  ChartTheme get theme => widget.theme;

  String get title => info.title;

  @override
  Widget build(BuildContext context){
    double plotWidth = size.width;
    double plotHeight = size.height;

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
              // The main plot area
              Positioned(
                top: 0,
                left: size.width - plotWidth,
                child: GestureDetector(
                    onTap: (){
                      dataCenter.updateSelected();
                    },
                    child: Container(
                        width: plotWidth,
                        height: plotHeight,
                        decoration: BoxDecoration(
                          color: theme.themeData.colorScheme.background,
                        ),
                        child: Builder(
                            builder: (BuildContext context){
                              final List<Widget> children = [];
                              final Size plotSize = Size(plotWidth, plotHeight);

                              if(rAxis.bounds != null){
                                Projection2D projection = Polar2DProjection.fromAxes(
                                  rAxis: rAxis,
                                  thetaAxis: thetaAxis,
                                  plotSize: plotSize,
                                );

                                children.addAll(getMarkers(
                                  projection: projection,
                                  plotSize: plotSize,
                                  axes: [rAxis, thetaAxis],
                                ));

                                children.addAll(getSelectedMarkers(
                                  projection: projection,
                                  plotSize: plotSize,
                                  axes: [rAxis, thetaAxis],
                                ));
                              }
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
*/
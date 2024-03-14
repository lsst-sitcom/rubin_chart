import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rubin_chart/src/models/axes/axis.dart';
import 'package:rubin_chart/src/models/axes/projection.dart';
import 'package:rubin_chart/src/models/axes/ticks.dart';
import 'package:rubin_chart/src/models/marker.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/ui/axis_painter.dart';
import 'package:rubin_chart/src/ui/chart.dart';
import 'package:rubin_chart/src/utils/utils.dart';

/// A single bin in a histogram.
class HistogramBin {
  final double start;
  final double end;
  final Color? fillColor;
  final Color? edgeColor;
  final double edgeWidth;
  int count;

  HistogramBin({
    required this.start,
    required this.end,
    required this.count,
    this.fillColor,
    this.edgeColor,
    this.edgeWidth = 1,
  });

  @override
  String toString() {
    return "HistogramBin(start: $start, end: $end, count: $count)";
  }
}

/// A collection of bins in a histogram.
class HistogramBins {
  /// The bins in the histogram.
  final List<HistogramBin> bins;

  /// The number of data points that did not fit into any bin.
  int missingData = 0;

  HistogramBins(this.bins);

  /// Insert a data point into the histogram.
  bool insert(double data) {
    for (HistogramBin bin in bins) {
      if (bin.start <= data && data < bin.end) {
        bin.count++;
        return true;
      }
    }
    // The data point did not fit into any bin.
    missingData++;
    return false;
  }

  /// Insert a list of data points into the histogram.
  /// The number of data points that did not fit into any bin is returned.
  int insertAll(List<double> data) {
    for (double d in data) {
      insert(d);
    }
    return missingData;
  }
}

/// Information for a histogram chart
@immutable
class HistogramInfo<T extends Object> extends ChartInfo {
  /// The number of bins to use
  /// Either [nBins] or [edges] must be provided.
  final int? nBins;

  /// Whether to fill the bins or leave them as outlines.
  final bool doFill;

  /// The bins to use for the histogram.
  /// Either nBins or bins must be provided.
  final List<T>? edges;

  HistogramInfo({
    required super.id,
    required super.allSeries,
    super.title,
    super.theme,
    super.legend,
    super.axisInfo,
    super.colorCycle,
    super.projectionInitializer = CartesianProjection.fromAxes,
    super.interiorAxisLabelLocation,
    super.flexX,
    super.flexY,
    this.nBins,
    this.doFill = true,
    this.edges,
  })  : assert(nBins != null || edges != null),
        super(builder: Histogram.builder);
}

class Histogram<T extends Object> extends StatefulWidget {
  final HistogramInfo<T> info;
  final SelectionController? selectionController;
  final Map<AxisId, AxisController> axisControllers;
  final List<AxisId> hiddenAxes;

  const Histogram({
    super.key,
    required this.info,
    this.selectionController,
    this.axisControllers = const {},
    this.hiddenAxes = const [],
  });

  @override
  HistogramState createState() => HistogramState();

  static Widget builder({
    required ChartInfo info,
    Map<AxisId, AxisController>? axisControllers,
    SelectionController? selectionController,
    List<AxisId>? hiddenAxes,
  }) {
    return Histogram(
      info: info as HistogramInfo,
      selectionController: selectionController,
      axisControllers: axisControllers ?? {},
      hiddenAxes: hiddenAxes ?? [],
    );
  }
}

class HistogramState<T extends Object> extends State<Histogram<T>> with ChartMixin, Scrollable2DChartMixin {
  @override
  SeriesList get seriesList => SeriesList(
        widget.info.allSeries,
        widget.info.colorCycle ?? widget.info.theme.colorCycle,
      );

  /// The axes of the chart.
  @override
  Map<Object, ChartAxes> get axes => _axes;

  /// The axes of the chart.
  final Map<Object, ChartAxes> _axes = {};

  final Map<BigInt, HistogramBins> _allBins = {};

  @override
  void initState() {
    super.initState();

    axisControllers.addAll(widget.axisControllers.values);
    if (widget.selectionController != null) {
      widget.selectionController!.subscribe((List<Object> dataPoints) {
        selectedDataPoints = dataPoints;
        setState(() {});
      });
    }

    // Initialize the axes
    _axes.addAll(initializeSimpleAxes(
      seriesList: widget.info.allSeries,
      axisInfo: widget.info.axisInfo,
      theme: widget.info.theme,
      projectionInitializer: widget.info.projectionInitializer,
    ));

    if (_axes.length != 1) {
      throw Exception('Histograms must have exactly one axis');
    }

    /// Histograms only have a single axis, so we can just use the first one.
    ChartAxis xAxis = _axes.values.first.axes.values.first;
    PixelTransform xTransform = PixelTransform.fromAxis(axis: xAxis, plotSize: 1);

    List<double> edges = [];
    if (widget.info.edges != null) {
      for (T edge in widget.info.edges!) {
        edges.add(xAxis.toDouble(edge));
      }
    } else {
      if (widget.info.nBins == null) {
        throw Exception('Either nBins or edges must be provided');
      }
      // Create bins using the correct mapping to give the bins equal width in the image.
      // If a non-linear scaling is used, such as log scaling, that will be accounted
      // for in the bin edges.
      double binWidth = 1 / widget.info.nBins!;
      for (int i = 0; i < widget.info.nBins!; i++) {
        edges.add(xTransform.inverse(i * binWidth));
      }
    }

    for (int i = 0; i < widget.info.allSeries.length; i++) {
      Series series = widget.info.allSeries[i];
      _allBins[series.id] = HistogramBins(
        List.generate(edges.length - 1, (j) {
          return HistogramBin(
            start: edges[j],
            end: edges[j + 1],
            count: 0,
            fillColor:
                series.marker?.color ?? widget.info.theme.colorCycle[i % widget.info.theme.colorCycle.length],
            edgeColor: series.marker?.edgeColor,
            edgeWidth: (series.marker?.size ?? 10) / 10,
          );
        }),
      );
      _allBins[series.id]!.insertAll(series.data.data[series.data.plotColumns.values.first]!.values
          .toList()
          .map((e) => xAxis.toDouble(e))
          .toList());
    }

    // Create the y-axis
    final maxCount = _allBins.values
        .expand((histogramBins) => histogramBins.bins)
        .map((bin) => bin.count)
        .reduce((a, b) => a > b ? a : b);
    ChartAxisInfo? yAxisInfo;
    for (AxisId id in widget.info.axisInfo.keys) {
      if (id.location == AxisLocation.left || id.location == AxisLocation.right) {
        yAxisInfo = widget.info.axisInfo[id];
        break;
      }
    }
    if (yAxisInfo == null) {
      AxisId yAxisId = AxisId(AxisLocation.left, xAxis.info.axisId.axesId);
      yAxisInfo = ChartAxisInfo(
        label: "count",
        axisId: yAxisId,
      );
    }

    NumericalChartAxis yAxis = NumericalChartAxis.fromData(
      data: [Bounds(0, maxCount.toDouble())],
      axisInfo: yAxisInfo,
      theme: widget.info.theme,
    );
    _axes.values.first.axes[yAxis.info.axisId] = yAxis;

    if (widget.axisControllers.containsKey(xAxis.info.axisId)) {
      xAxis.controller = widget.axisControllers[xAxis.info.axisId];
    }
    if (widget.hiddenAxes.contains(xAxis.info.axisId)) {
      xAxis.showLabels = false;
    }

    // Subscribe to the axis controllers
    for (AxisController controller in axisControllers) {
      controller.subscribe(({Bounds? bounds, AxisTicks? ticks, ChartAxisInfo? info}) {
        xAxis.update(bounds: bounds, ticks: ticks, info: info, state: this);
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];

    AxisPainter axisPainter = AxisPainter(
      allAxes: _axes,
      theme: widget.info.theme,
    );

    // Draw the axes
    children.add(
      Positioned.fill(
        child: CustomPaint(
          painter: axisPainter,
        ),
      ),
    );

    // Add a BarPainter widget for each [Series].
    int colorIndex = 0;
    for (int i = 0; i < seriesList.length; i++) {
      if (colorIndex >= widget.info.theme.colorCycle.length) {
        colorIndex = 0;
      }
      Series series = seriesList[i];
      children.add(
        Positioned.fill(
          child: CustomPaint(
            painter: HistogramPainter(
              axes: _axes[series.axesId]!,
              errorBars: series.errorBars,
              allBins: _allBins,
              tickLabelMargin: EdgeInsets.only(
                left: axisPainter.margin.left + axisPainter.tickPadding,
                right: axisPainter.margin.right + axisPainter.tickPadding,
                top: axisPainter.margin.top + axisPainter.tickPadding,
                bottom: axisPainter.margin.bottom + axisPainter.tickPadding,
              ),
            ),
          ),
        ),
      );
    }

    // Add the selection box if the user is dragging
    if (dragging) {
      children.add(Positioned(
        left: math.min(dragStart!.dx, dragEnd!.dx),
        top: math.min(dragStart!.dy, dragEnd!.dy),
        child: Container(
          width: (dragEnd!.dx - dragStart!.dx).abs(),
          height: (dragEnd!.dy - dragStart!.dy).abs(),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.blue,
              width: 2,
            ),
          ),
        ),
      ));
    }

    return Listener(
        onPointerSignal: (PointerSignalEvent event) {
          if (event is PointerScrollEvent) {
            onPan(event, axisPainter);
          } else if (event is PointerScaleEvent) {
            onScale(event, axisPainter);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          /*onTapUp: (TapUpDetails details) {
            _onTapUp(details, axisPainter);
          },
          onPanStart: (DragStartDetails details) {
            _onDragStart(details, axisPainter);
          },
          onPanUpdate: (DragUpdateDetails details) {
            _onDragUpdate(details, axisPainter);
          },
          onPanEnd: (DragEndDetails details) {
            _onDragEnd(details, axisPainter);
          },
          onPanCancel: () {
            _onDragCancel();
          },*/
          child: Container(
            /*decoration: BoxDecoration(
              border: Border.all(
                color: Colors.red,
                width: 2,
              ),
              //borderRadius: BorderRadius.circular(10),
            ),*/
            child: Stack(children: children),
          ),
        ));
  }
}

/// A painter for a collection of histograms.
class HistogramPainter extends CustomPainter {
  /// The axes of the plot, used to project the markers onto the plot.
  final ChartAxes axes;

  /// The bins to draw
  final Map<BigInt, HistogramBins> allBins;

  /// The error bar style used for the series.
  final ErrorBars? errorBars;

  /// Offset from the lower left to make room for labels.
  final EdgeInsets tickLabelMargin;

  HistogramPainter({
    required this.axes,
    required this.errorBars,
    required this.allBins,
    this.tickLabelMargin = EdgeInsets.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    print("painting histogram");
    // Calculate the projection used for all points in the series
    Size plotSize = Size(size.width - tickLabelMargin.left - tickLabelMargin.right,
        size.height - tickLabelMargin.top - tickLabelMargin.bottom);
    Rect plotWindow = Offset(tickLabelMargin.left, tickLabelMargin.top) & plotSize;
    Offset offset = Offset(tickLabelMargin.left, tickLabelMargin.top);
    Projection projection = axes.projection(
      axes: axes.axes.values.toList(),
      plotSize: plotSize,
    );

    // Since all of the objects in the series use the same marker style,
    // we can calculate the [Paint] objects once and reuse them.
    double lastY = 0;
    double y0 = projection.yTransform.map(0) + offset.dy;
    for (HistogramBins bins in allBins.values) {
      for (int i = 0; i < bins.bins.length; i++) {
        HistogramBin bin = bins.bins[i];
        // Create the painters for the edge and fill of the bin
        Color? fillColor = bin.fillColor;
        Color? edgeColor = bin.edgeColor;
        Paint? paintFill;
        Paint? paintEdge;
        if (fillColor != null) {
          paintFill = Paint()..color = fillColor;
        }
        if (edgeColor != null) {
          paintEdge = Paint()
            ..color = edgeColor
            ..strokeWidth = bin.edgeWidth
            ..style = PaintingStyle.stroke;
        }

        // Calculate the pixel coordinates of the bin
        double left = projection.xTransform.map(bin.start) + offset.dx;
        double right = projection.xTransform.map(bin.end) + offset.dx;
        double last = projection.yTransform.map(lastY) + offset.dy;
        double bottom = projection.yTransform.map(bin.count) + offset.dy;
        Rect binRect = Rect.fromLTRB(left, y0, right, bottom);

        print(plotWindow);
        print(binRect);

        if (binRect.overlaps(plotWindow)) {
          print("$bin has overlap");
          // Paint the bin
          if (paintFill != null) {
            canvas.drawRect(
              Rect.fromLTRB(left, y0, right, bottom),
              paintFill,
            );
          }
          // Draw the edge
          if (paintEdge != null) {
            canvas.drawLine(Offset(left, last), Offset(left, y0), paintEdge);
            canvas.drawLine(Offset(left, bottom), Offset(right, bottom), paintEdge);
            if (i == bins.bins.length - 1) {
              canvas.drawLine(Offset(right, bottom), Offset(right, y0), paintEdge);
            }
          }
        }
        lastY = bin.count.toDouble();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // TODO: imporve repaint logic
    return true;
  }
}

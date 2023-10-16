import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rubin_chart/src/chart/chart.dart';
import 'package:rubin_chart/src/core/data.dart';
import 'package:rubin_chart/src/chart/mapping.dart';
import 'package:rubin_chart/src/chart/projection.dart';
import 'package:rubin_chart/src/core/utils.dart';
import 'package:rubin_chart/src/state/action.dart';
import 'package:rubin_chart/src/state/theme.dart';


/// Update the [PlotAxis] for a given [Chart].
class AxisUpdate extends UiAction {
  final Chart chart;
  final PlotAxis newAxis;
  final int axisIndex;

  const AxisUpdate({
    required this.chart,
    required this.newAxis,
    required this.axisIndex,
  });
}


/// The orientation of a plot axis
enum AxisOrientation {
  vertical,
  horizontal,
  radial,
  angular,
}


/// Major or minor ticks for a [PlotAxis].
class AxisTicks {
  /// Factor that all of the ticks are multiples of.
  final double tickFactor;
  /// The ticks on the axis.
  final List<double> ticks;
  /// The label for each tick (optional for a minor axis).
  final List<String>? labels;

  const AxisTicks({
    required this.tickFactor,
    required this.ticks,
    this.labels,
  });

  /// The bounds of the tick marks
  Bounds get bounds => Bounds(ticks.first, ticks.last);
}


/// This algorithm is from Graphics Gems, by Andrew Glassner,
/// in the chapter "Nice Numbers for Graph Labels" to generate numbers
/// that are a factor of 1, 2, 5, or 10, hence the term "Nice Numbers."
double getNiceNumber(double x, bool round){
  double logX = log(x)/ln10;
  int power = logX.floor();

  double nearest10 = pow(10, power).toDouble();
  // The factor will be between ~1 and ~10 (with some rounding errors)
  double factor = x / nearest10;

  if(round){
    if(factor < 1.5){
      factor = 1;
    } else if(factor < 3){
      factor = 2;
    } else if (factor < 7){
      factor = 5;
    } else {
      factor = 10;
    }
  } else {
    if(factor <= 1){
      factor = 1;
    } else if(factor <= 2){
      factor = 2;
    } else if(factor <=5){
      factor = 5;
    } else {
      factor = 10;
    }
  }
  return factor * nearest10;
}


/// This algorithm is from Graphics Gems, by Andrew Glassner,
/// in the chapter "Nice Numbers for Graph Labels" to make an
/// axis range from a minimum value to a maximum value in numbers
/// that are a factor of 1, 2, 5, or 10.
AxisTicks getMajorTicks({
  required double min,
  required double max,
  required int nTicks,
}){
  double range = getNiceNumber(max-min, false);
  double tick = getNiceNumber(range/(nTicks -1), true);
  double minTick = (min/tick).floor()*tick;

  List<double> majorTicks = List.generate(nTicks, (t)=>minTick + t*tick);
  if(majorTicks.last < max){
    majorTicks.add(min + tick*nTicks);
  }
  List<String> labels = tickToString(ticks: majorTicks, tickFactor: tick);

  return AxisTicks(
    tickFactor: tick,
    ticks: majorTicks,
    labels: labels,
  );
}


/// The significant figures in a number
int getSigFig(num x){
  String xStr = x.toString();
  List<String> split = xStr.split(".");

  if(split.length == 1 || split[1] == "0"){
    return trimStringRight(split[0], "0").length;
  }
  int leftSig = split[0] == "0" ? 0 : split[0].length;
  if(leftSig == 0){
    return trimStringLeft(split[1], "0").length + leftSig;
  }
  return split[1].length + leftSig;
}


List<String> tickToString({
  required List<double> ticks,
  required double? tickFactor,
  int? precision,
}){
  List<String> labels = [];
  if(tickFactor != null && tickFactor == tickFactor.toInt()){
    for(double x in ticks){
      labels.add(x.toInt().toString());
    }
  } else {
    if(precision == null){
      if(tickFactor == null){
        throw ArgumentError("Must either specify `tickFactor` or `precision`, got `null` for both.");
      }
      precision = getSigFig(tickFactor);
    }

    for(double x in ticks){
      labels.add(x.toStringAsPrecision(precision));
    }
  }

  return labels;
}


/// Plot axis contains information about orientation, range, and mapping function
/// for points along that axis.
class PlotAxis {
  /// The orientation of the axis.
  final AxisOrientation orientation;
  /// Label of the axis in a plot.
  final String label;
  /// The max/min bounds of the axis displayed in a plot.
  final Bounds bounds;
  /// A mapping function that maps a number to the axis coordinate system.
  /// This is usually just a linear mapping but can, for example, be a log mapping.
  final Mapping mapping;
  /// Whether or not the bounds are fixed.
  final bool boundsFixed;
  /// Major tick marks plotted on the axis.
  final AxisTicks majorTicks;
  /// Minor tick marks plotted on the axis.
  final AxisTicks? minorTicks;
  /// Number of major tick marks.
  final int nMajorTicks;
  /// Number of minor tick marks.
  final int nMinorTicks;
  /// [bounds] scaled to match the pixel locations in the plot [Widget].
  final Bounds plotBounds;
  /// True if the displayed axis is inverted
  final bool isInverted;

  const PlotAxis({
    required this.label,
    required this.bounds,
    required this.mapping,
    required this.orientation,
    this.boundsFixed = false,
    required this.majorTicks,
    this.minorTicks,
    this.nMajorTicks = 5,
    this.nMinorTicks = 5,
    this.isInverted = false,
    required this.plotBounds,
  });

  static PlotAxis fromParameters({
    required String label,
    required Bounds bounds,
    Mapping mapping = const LinearMapping(),
    required AxisOrientation orientation,
    bool boundsFixed = false,
    AxisTicks? majorTicks,
    AxisTicks? minorTicks,
    int nMajorTicks = 5,
    int nMinorTicks = 5,
    bool isInverted = false,
    Bounds? plotBounds,
  }){
    plotBounds ??= Bounds(mapping.map(bounds.min), mapping.map(bounds.max));
    majorTicks ??= getMajorTicks(
      min: plotBounds.min.toDouble(),
      max: plotBounds.max.toDouble(),
      nTicks: nMajorTicks,
    );

    return PlotAxis(
      label: label,
      bounds: bounds,
      mapping: mapping,
      orientation: orientation,
      boundsFixed: boundsFixed,
      majorTicks: majorTicks,
      minorTicks: minorTicks,
      nMajorTicks: nMajorTicks,
      nMinorTicks: nMinorTicks,
      isInverted: isInverted,
      plotBounds: plotBounds,
    );
  }

  PlotAxis copyWith({
    String? label,
    Bounds? bounds,
    Mapping? mapping,
    AxisOrientation? orientation,
    bool? boundsFixed,
    AxisTicks? majorTicks,
    AxisTicks? minorTicks,
    int? nMajorTicks,
    int? nMinorTicks,
    bool? isInverted,
    Bounds? plotBounds,
  }){
    bool fixed = boundsFixed ?? this.boundsFixed;

    if((bounds != null || mapping != null) && !fixed){
      mapping ??= this.mapping;
      bounds ??= this.bounds;
      nMajorTicks ??= this.nMajorTicks;

      plotBounds ??= Bounds(mapping.map(bounds.min), mapping.map(bounds.max));
      majorTicks ??= getMajorTicks(
        min: plotBounds.min.toDouble(),
        max: plotBounds.max.toDouble(),
        nTicks: nMajorTicks,
      );
    }

    return PlotAxis(
      label: label ?? this.label,
      bounds: bounds ?? this.bounds,
      mapping: mapping ?? this.mapping,
      orientation: orientation ?? this.orientation,
      boundsFixed: boundsFixed ?? this.boundsFixed,
      majorTicks: majorTicks ?? this.majorTicks,
      minorTicks: minorTicks ?? this.minorTicks,
      nMajorTicks: nMajorTicks ?? this.nMajorTicks,
      nMinorTicks: nMinorTicks ?? this.nMinorTicks,
      isInverted: isInverted ?? this.isInverted,
      plotBounds: plotBounds ?? this.plotBounds,
    );
  }

  /// Make a copy of this [PlotAxis].
  PlotAxis copy() => copyWith();

  Bounds? get tickBounds => Bounds(majorTicks.ticks.first, majorTicks.ticks.last);

  @override
  String toString() => "PlotAxis<$label>(${bounds.min}-${bounds.max}";
}


/// Paint tick marks on an axis
class TickMarkPainter extends CustomPainter {
  /// The theme of the plot
  final ChartTheme theme;
  /// The major ticks to mark
  final PlotAxis axis;
  /// The transform from [PlotAxis] (tick) coordinates to plot coordinates
  final PlotTransform? transform;
  /// The size of the canvas
  final Size size;
  /// Offset from the edge of the axis [Widget] to the edge of the plot, in pixel coordinates.
  final double plotOffset;

  TickMarkPainter({
    required this.theme,
    required this.transform,
    required this.axis,
    required this.size,
    required this.plotOffset,
  });

  /// Draw ticks for a horizontal axis
  void drawHorizontalTicks({
    required AxisTicks ticks,
    required Canvas canvas,
    required Paint paint,
    required double length
  }){
    for(int i=0; i<ticks.ticks.length; i++) {
      double x = transform!.map(ticks.ticks[i]);
      //print("horizontal: ${ticks.ticks[i]}->$x");
      canvas.drawLine(
        Offset(x + plotOffset, 0),
        Offset(x + plotOffset, length),
        paint,
      );

      if(ticks.labels != null){
        final TextSpan labelSpan = TextSpan(
          text: ticks.labels![i],
          style: theme.axisLabelStyle,
        );

        final TextPainter textPainter = TextPainter(
          text: labelSpan,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout(
          minWidth: 0,
          maxWidth: size.width,
        );

        final Offset offset = Offset(
          x + plotOffset - textPainter.width/2,
          length + theme.axisLabelPadding,
        );

        textPainter.paint(canvas, offset);
      }
    }
  }

  /// Draw ticks for a veritcal axis
  void drawVerticalTicks({
    required AxisTicks ticks,
    required Canvas canvas,
    required Paint paint,
    required double length
  }){
    for(int i=0; i<ticks.ticks.length; i++) {
      double x = transform!.map(ticks.ticks[i]);
      //print("vertical: ${ticks.ticks[i]}->$x");
      canvas.drawLine(
        Offset(x + plotOffset, size.height),
        Offset(x + plotOffset, size.height-length),
        paint,
      );

      if(ticks.labels != null){
        final TextSpan labelSpan = TextSpan(
          text: ticks.labels![i],
          style: theme.axisLabelStyle,
        );

        final TextPainter textPainter = TextPainter(
          text: labelSpan,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout(
          minWidth: 0,
          maxWidth: size.width,
        );

        final Offset offset = Offset(
          x + plotOffset - textPainter.width/2,
          length + theme.axisLabelPadding,
        );

        textPainter.paint(canvas, offset);
      }
    }
  }

  /// Paint the marks on the canvas
  @override
  void paint(Canvas canvas, Size size){
    final Paint majorPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = theme.majorTickWidth
        ..color = theme.axisColor;

    final Paint minorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = theme.minorTickWidth
      ..color = theme.axisColor;

    // Layout the axis label
    final TextSpan labelSpan = TextSpan(
      text: axis.label,
      style: theme.axisLabelStyle,
    );

    final TextPainter textPainter = TextPainter(
      text: labelSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(
      minWidth: 0,
      maxWidth: size.width,
    );

    if(axis.orientation == AxisOrientation.horizontal){
      // Draw the major ticks
      drawHorizontalTicks(
        ticks: axis.majorTicks,
        canvas: canvas,
        paint: majorPaint,
        length: theme.majorTickLength,
      );

      if(axis.minorTicks != null){
        // Draw the minor ticks
        drawHorizontalTicks(
          ticks: axis.minorTicks!,
          canvas: canvas,
          paint: minorPaint,
          length: theme.minorTickLength,
        );
      }

      // Paint the label
      final Offset offset = Offset(
        (size.width - textPainter.width)/2,
        theme.minorTickLength + textPainter.height + 2*theme.axisLabelPadding,
      );
      textPainter.paint(canvas, offset);
    }else if(axis.orientation == AxisOrientation.vertical){
      // Draw the major ticks
      drawVerticalTicks(
        ticks: axis.majorTicks,
        canvas: canvas,
        paint: majorPaint,
        length: theme.majorTickLength,
      );

      if(axis.minorTicks != null){
        // Draw the minor ticks
        drawVerticalTicks(
          ticks: axis.minorTicks!,
          canvas: canvas,
          paint: minorPaint,
          length: theme.minorTickLength,
        );
      }
      // Paint the label
      final Offset offset = Offset(
        (size.width - textPainter.width)/2,
        theme.axisLabelPadding,
      );
      textPainter.paint(canvas, offset);
    } else {
      throw ArgumentError(
          "Unexpected axis orientation. Must be either horizontal or vertical, got ${axis.orientation}"
      );
    }
  }

  @override
  bool shouldRepaint(TickMarkPainter oldDelegate) =>
      axis != oldDelegate.axis || transform != oldDelegate.transform;
}


/// Draw ticks on a [Widget] for a [PlotAxis].
class TicksWidget extends StatelessWidget{
  final ChartTheme theme;
  final PlotAxis axis;
  final PlotTransform? transform;
  final Size size;
  final double plotOffset;

  const TicksWidget({
    super.key,
    required this.theme,
    required this.plotOffset,
    required this.axis,
    required this.transform,
    required this.size,
  });

  @override
  Widget build(BuildContext context){
    return SizedBox(
        width: size.width,
        height: size.height,
        child: CustomPaint(
          painter: TickMarkPainter(
              theme: theme,
              axis: axis,
              transform: transform,
              size: size,
              plotOffset: plotOffset
          ),
        )
    );
  }
}


class VerticalAxisWidget extends StatelessWidget {
  final ChartTheme theme;
  final PlotAxis axis;
  final Size size;
  final PlotTransform? transform;
  final double plotOffset;

  const VerticalAxisWidget({
    super.key,
    required this.theme,
    required this.axis,
    required this.size,
    required this.transform,
    required this.plotOffset,
  });

  // TODO: make this functional
  static double getWidth({
    required ChartTheme theme,
    required PlotAxis axis,
  }) => 30;

  @override
  Widget build(BuildContext context){
    // Since we're rotating the container, we switch the width and height for the pre-rotated layout
    return RotatedBox(
      quarterTurns: -1,
      child: SizedBox(
        width: size.height,
        height: size.width,
        child: TicksWidget(
          axis: axis,
          transform: transform,
          theme: theme,
          size: Size(size.height, size.width),
          plotOffset: plotOffset,
        ),
      ),
    );
  }
}


/// Draw the horizontal [PlotAxis], including the label.
class HorizontalAxisWidget extends StatelessWidget {
  final ChartTheme theme;
  final PlotAxis axis;
  final Size size;
  final PlotTransform? transform;
  final double plotOffset;

  const HorizontalAxisWidget({
    super.key,
    required this.theme,
    required this.axis,
    required this.size,
    required this.transform,
    required this.plotOffset,
  });

  // TODO: make this functional
  static double getHeight({
    required ChartTheme theme,
    required PlotAxis axis,
  }) => 30;

  @override
  Widget build(BuildContext context){
    return SizedBox(
      width: size.width,
      height: size.height,
      child: TicksWidget(
        axis: axis,
        transform: transform,
        theme: theme,
        size: size,
        plotOffset: plotOffset,
      ),
    );
  }
}


/// Edit parameters for a [PlotAxis].
class AxisEditor extends StatefulWidget {
  final ChartTheme theme;
  final Chart info;
  final PlotAxis? axis;
  final DataCenter dataCenter;
  final DispatchAction dispatch;
  final String title;
  final int axisIndex;
  final AxisOrientation orientation;
  final Bounds dataBounds;

  const AxisEditor({
    super.key,
    required this.title,
    required this.theme,
    required this.info,
    required this.axis,
    required this.dataCenter,
    required this.dispatch,
    required this.axisIndex,
    required this.orientation,
    required this.dataBounds,
  });

  @override
  AxisEditorState createState() => AxisEditorState();
}


/// [State] for an [AxisEditor].
class AxisEditorState extends State<AxisEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  ChartTheme get theme => widget.theme;
  late PlotAxis axis;
  DataCenter get dataCenter => widget.dataCenter;
  RangeValues get _currentRangeValues => RangeValues(axis.bounds.min.toDouble(), axis.bounds.max.toDouble());

  TextEditingController columnMinController = TextEditingController();
  TextEditingController columnMaxController = TextEditingController();
  Bounds get columnBounds => widget.dataBounds;
  Bounds get _rangeBounds {
    double min = axis.bounds.min.toDouble();
    double max = axis.bounds.max.toDouble();
    if(columnBounds.min < min){
      min = columnBounds.min.toDouble();
    }
    if(columnBounds.max > max){
      max = columnBounds.max.toDouble();
    }
    return Bounds(min, max);
  }

  final MaterialStateProperty<Icon?> thumbIcon = MaterialStateProperty.resolveWith<Icon?>(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return const Icon(Icons.check);
          }
          return const Icon(Icons.close);
        },
  );

  IconData get _icon => axis.boundsFixed
      ? Icons.lock
      : Icons.lock_open;

  Color get _iconColor => axis.boundsFixed
      ? theme.themeData.colorScheme.secondary
      : theme.themeData.colorScheme.tertiary;

  @override
  void initState(){
    super.initState();
    axis = widget.axis!.copy();
    columnMinController.text = "${_rangeBounds.min}";
    columnMaxController.text = "${_rangeBounds.max}";
  }

  @override
  Widget build(BuildContext context){
    final List<DropdownMenuItem<Mapping>> mappingEntries = [
      const DropdownMenuItem(value: LinearMapping(), child: Text("linear")),
      const DropdownMenuItem(value: Log10Mapping(), child: Text("log")),
    ];

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 400,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Text(widget.title, style: widget.theme.editorTitleStyle),
                ),
                const SizedBox(height: 20,),
                TextFormField(
                  initialValue: axis.label,
                  onChanged: (String? value){
                    axis = axis.copyWith(label: value);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    IntrinsicWidth(
                      child: DropdownButtonFormField<Mapping>(
                        decoration: widget.theme.queryTextDecoration.copyWith(
                          labelText: "scale",
                        ),
                        value: axis.mapping,
                        items: mappingEntries,
                        onChanged: (Mapping? value){
                          if(value != null){
                            axis = axis.copyWith(mapping: value);
                          }
                        }
                      ),
                    ),
                    const Spacer(),
                    const Text("invert"),
                    Switch(
                      thumbIcon: thumbIcon,
                      value: axis.isInverted,
                      onChanged: (bool value){
                        setState(() {
                          axis = axis.copyWith(isInverted: value);
                        });
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(_icon, color: _iconColor),
                      onPressed: (){
                        setState(() {
                          axis = axis.copyWith(boundsFixed: !axis.boundsFixed);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        controller: columnMinController,
                        onChanged: (String? value){
                          if(value != null){
                            double? min = double.tryParse(value);
                            if(min != null){
                              setState(() {
                                axis = axis.copyWith(bounds: Bounds(min, axis.bounds.max));
                              });
                            }
                          }
                        },
                      ),
                    ),
                    RangeSlider(
                      values: _currentRangeValues,
                      min: _rangeBounds.min.toDouble(),
                      max: _rangeBounds.max.toDouble(),
                      onChanged: (RangeValues values){
                        setState(() {
                          axis = axis.copyWith(bounds: Bounds(values.start, values.end));
                          columnMinController.text = axis.bounds.min.toStringAsPrecision(7);
                          columnMaxController.text = axis.bounds.max.toStringAsPrecision(7);
                        });
                      },
                    ),
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        controller: columnMaxController,
                        onChanged: (String? value){
                          if(value != null){
                            double? max = double.tryParse(value);
                            if(max != null){
                              setState(() {
                                axis = axis.copyWith(bounds: Bounds(axis.bounds.min, max));
                              });
                            }
                          }
                        },
                      ),
                    ),
                  ]
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      onPressed: (){
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.cancel, color: Colors.red),
                    ),
                    IconButton(
                      onPressed: (){
                        if (_formKey.currentState!.validate()) {
                          widget.dispatch(AxisUpdate(
                            chart: widget.info,
                            newAxis: axis,
                            axisIndex: widget.axisIndex,
                          ));
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                    ),
                  ],
                ),
              ]
          ),
        ),
      ),
    );
  }
}

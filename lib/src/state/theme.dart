import 'package:flutter/material.dart';


const List<Color> defaultColorCycle = [
  Color(0xFFE6194B),
  Color(0xFF3CB44B),
  Color(0xFFFFE119),
  Color(0xFF0082C8),
  Color(0xFFF58231),
  Color(0xFF911EB4),
  Color(0xFF46F0F0),
  Color(0xFFF032E6),
  Color(0xFFD2F53C),
  Color(0xFFFABEBE),
  Color(0xFF008080),
  Color(0xFFE6BEFF),
  Color(0xFFAA6E28),
  Color(0xFFFFFAC8),
  Color(0xFF800000),
  Color(0xFFAAFFC3),
  Color(0xFF808000),
  Color(0xFFFFD8B1),
  Color(0xFF000080),
  Color(0xFF808080),
  Color(0xFFFFFFFF),
  Color(0xFF000000),
];


Color invertColor(Color color) => Color.fromARGB(
  color.alpha,
  255 - color.red,
  255 - color.green,
  255 - color.blue,
);


class ChartTheme {
  final List<Color> colorCycle;
  final ThemeData themeData;
  final TextStyle _axisStyle;
  final TextStyle _axisLabelStyle;
  final TextStyle _titleStyle;
  final TextStyle _legendStyle;
  final TextStyle _queryStyle;
  final TextStyle _editorTitleStyle;
  final double axisLabelPadding;
  final double majorTickLength;
  final double majorTickWidth;
  final double minorTickLength;
  final double minorTickWidth;
  final Color axisColor;
  final double querySpacerWidth;
  final Color wireColor;
  final Duration animationSpeed;
  final Offset newWindowOffset;
  final Size newPlotSize;
  final double resizeInteractionWidth;

  const ChartTheme({
    this.colorCycle = defaultColorCycle,
    required this.themeData,
    TextStyle axisStyle = const TextStyle(
      fontSize: 10,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      inherit: false,
      height: 1.0,
    ),
    TextStyle axisLabelStyle = const TextStyle(
      fontSize: 15,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      inherit: false,
      height: 1.0,
    ),
    TextStyle titleStyle = const TextStyle(
      fontSize: 20,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      inherit: false,
      height: 1.0,
    ),
    TextStyle legendStyle = const TextStyle(
      fontSize: 15,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      inherit: false,
      height: 1.0,
    ),
    TextStyle queryStyle = const TextStyle(
      fontSize: 20,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      inherit: false,
      height: 1.0,
    ),
    TextStyle editorTitleStyle = const TextStyle(
      fontSize: 30,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      inherit: false,
      height: 1.0,
    ),
    this.axisLabelPadding = 4,
    this.majorTickLength = 10,
    this.majorTickWidth = 2,
    this.minorTickLength = 5,
    this.minorTickWidth = 1,
    this.axisColor = Colors.black,
    this.querySpacerWidth = 10,
    this.wireColor = Colors.redAccent,
    this.animationSpeed = const Duration(milliseconds: 500),
    this.newWindowOffset = const Offset(20, 20),
    this.newPlotSize = const Size(600, 400),
    this.resizeInteractionWidth = kMinInteractiveDimension/4,
  }):
        _axisLabelStyle=axisLabelStyle,
        _axisStyle=axisStyle,
        _titleStyle=titleStyle,
        _legendStyle=legendStyle,
        _queryStyle=queryStyle,
        _editorTitleStyle=editorTitleStyle;

  TextStyle get axisStyle => _axisStyle.copyWith(color: themeData.colorScheme.primary);
  TextStyle get axisLabelStyle => _axisLabelStyle.copyWith(color: themeData.colorScheme.primary);
  TextStyle get titleStyle => _titleStyle.copyWith(color: themeData.colorScheme.primary);
  TextStyle get legendStyle => _legendStyle.copyWith(color: themeData.colorScheme.secondary);
  TextStyle get queryStyle => _queryStyle.copyWith(color: themeData.colorScheme.primary);
  TextStyle get queryOperatorStyle => _queryStyle.copyWith(color: themeData.colorScheme.secondary);
  TextStyle get editorTitleStyle => _editorTitleStyle.copyWith(color: themeData.colorScheme.primary);

  Color getMarkerColor(int index) => colorCycle[index % colorCycle.length];
  Color? getMarkerEdgeColor(int index) => null;

  Color get selectionColor => themeData.colorScheme.primaryContainer;
  Color get selectionEdgeColor => themeData.primaryColor;

  InputDecorationTheme get queryTextDecorationTheme => InputDecorationTheme(
    border: OutlineInputBorder(
      borderSide: BorderSide(
      color: themeData.primaryColorDark,
      ),
    ),
    //contentPadding: const EdgeInsets.symmetric(vertical: 5.0),
  );

  InputDecoration get queryTextDecoration => InputDecoration(
    border: OutlineInputBorder(
      borderSide: BorderSide(
        color: themeData.primaryColorDark,
      ),
    ),
    //contentPadding: const EdgeInsets.symmetric(vertical: 5.0),
  );

  /// Alternate between secondary and tertiary container colors for the operators
  Color operatorQueryColor(int depth) => [
    themeData.colorScheme.secondaryContainer,
    themeData.colorScheme.tertiaryContainer,
  ][depth % 2];
}

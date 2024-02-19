import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/legend.dart';
import 'package:rubin_chart/src/models/marker.dart';
import 'package:rubin_chart/src/models/series.dart';
import 'package:rubin_chart/src/theme/theme.dart';

class LegendEntry extends StatelessWidget {
  final Marker marker;
  final String label;

  const LegendEntry({super.key, required this.marker, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: marker.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(label),
      ],
    );
  }
}

class VerticalLegendViewer extends StatelessWidget {
  final Legend legend;
  final ChartTheme theme;
  final SeriesList seriesList;

  const VerticalLegendViewer(
      {super.key, required this.legend, required this.theme, required this.seriesList});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.legendBorderColor,
          width: theme.legendBorderWidth,
        ),
        borderRadius: BorderRadius.circular(theme.legendBorderRadius),
      ),
      child: ListView.builder(
        itemCount: seriesList.length,
        itemBuilder: (BuildContext context, int index) {
          return LegendEntry(
            marker: seriesList.getMarker(index),
            label: seriesList.values[index].name ?? "Series $index",
          );
        },
      ),
    );
  }
}

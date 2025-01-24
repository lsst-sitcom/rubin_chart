import 'dart:math';
import 'package:flutter/material.dart';
import 'package:rubin_chart/rubin_chart.dart';

void main() {
  runApp(const DebugHistogramApp());
}

class DebugHistogramApp extends StatelessWidget {
  const DebugHistogramApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Provide mock data and dependencies
    final mockSeries = [
      Series(
        id: "Mock Series",
        data: MockSeriesData(),
        marker: const Marker(
          color: Colors.blue,
          size: 5,
        ),
      )
    ];

    final histogramInfo = HistogramInfo(
      id: "Mock Histogram",
      allSeries: mockSeries,
      nBins: 10,
      axisInfo: [
        ChartAxisInfo(
          label: "Mock Axis",
          axisId: AxisId(AxisLocation.bottom),
        ),
      ],
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Debugging Histogram Widget')),
        body: Center(
          child: Histogram(info: histogramInfo),
        ),
      ),
    );
  }
}

class MockSeriesData extends SeriesData {
  MockSeriesData()
      : super(
          data: {
            "x": generateRandomData(numberOfPoints: 100),
          },
          plotColumns: {
            AxisId(AxisLocation.bottom): "x",
          },
          columnTypes: {
            "x": ColumnDataType.number,
          },
        );
}

/// Generates random data points.
Map<int, double> generateRandomData({required int numberOfPoints}) {
  final random = Random();
  const double min = 0.0; // Minimum value
  const double max = 100.0; // Maximum value

  final Map<int, double> values = {};

  for (int x = 1; x <= numberOfPoints; x++) {
    values[x] = min + random.nextDouble() * (max - min);
  }

  return values;
}

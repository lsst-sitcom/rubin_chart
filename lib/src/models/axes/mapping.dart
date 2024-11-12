/// This file is part of the rubin_chart package.
///
/// Developed for the LSST Data Management System.
/// This product includes software developed by the LSST Project
/// (https://www.lsst.org).
/// See the COPYRIGHT file at the top-level directory of this distribution
/// for details of code ownership.
///
/// This program is free software: you can redistribute it and/or modify
/// it under the terms of the GNU General Public License as published by
/// the Free Software Foundation, either version 3 of the License, or
/// (at your option) any later version.
///
/// This program is distributed in the hope that it will be useful,
/// but WITHOUT ANY WARRANTY; without even the implied warranty of
/// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
/// GNU General Public License for more details.
///
/// You should have received a copy of the GNU General Public License
/// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:math' as math;
import 'dart:developer' as developer;

import 'package:rubin_chart/src/models/axes/ticks.dart';
import 'package:rubin_chart/src/utils/utils.dart';

/// An error occurred while mapping a value.
class MappingError implements Exception {
  MappingError(this.message);

  String? message;

  @override
  String toString() => "$runtimeType:\n\t$message";
}

/// A mapping between linear data values and (potentially) non-linear data values.
abstract class Mapping {
  const Mapping();

  /// Forward map the data value.
  double map(double x);

  /// Invert the mapping to get the data value.
  double inverse(double x);

  /// Get the ticks for the axis based on the bounds and the desired number of ticks.
  AxisTicks ticksFromBounds({
    required Bounds<num> bounds,
    required int minTicks,
    required int maxTicks,
    required bool encloseBounds,
  });

  /// Convert the mapping to a JSON object.
  Map<String, dynamic> toJson();

  /// Create a mapping from a JSON object.
  factory Mapping.fromJson(Map<String, dynamic> json) {
    switch (json["type"]) {
      case "linear":
        return const LinearMapping();
      case "log":
        return const LogMapping();
      case "log10":
        return const Log10Mapping();
      default:
        throw MappingError("Unknown mapping type: ${json['type']}");
    }
  }
}

/// Calculate the step size to generate ticks in [range].
/// If [encloseBounds] is true then ticks will be added to the
/// each side so that the bounds are included in the ticks
/// (usually used for initialization).
/// Otherwise the ticks will be inside or equal to the bounds.
NiceNumber calculateLinearTickStepSize(
  int nTicks,
  NiceNumber stepSize,
  num range,
  bool encloseBounds,
  int extrema,
  ComparisonOperators operator,
) {
  int iterations = 0;
  NiceNumber initialStepSize = stepSize;
  while (compare<num>(nTicks, extrema, operator)) {
    stepSize = stepSize.modifyFactor(-1);
    nTicks = (range / stepSize.value).ceil() + 1;
    if (encloseBounds) {
      nTicks += 2;
    }
    if (iterations++ > 5) {
      // Just use the original value
      developer.log("Warning: Could not find a nice number for the ticks", name: "rubin_chart.warning");
      return initialStepSize;
    }
  }
  return stepSize;
}

/// Get the ticks for a linear axis based on the step size.
List<T> getLinearTicksFromStepSize<T extends num>(T step, T min, T max, bool encloseBounds) {
  List<T> ticks = [];
  T val = min;

  // We use while loops below because dart cannot handle arithmentic with generic
  // types (ie. val += step is not allowed for generic types), preventing us
  // from using a for loop.
  if (encloseBounds) {
    // Make the ticks outside of the bounds
    while (val <= max + step) {
      ticks.add(val);
      val = (val + step) as T;
    }
  } else {
    // Make the ticks inside the bounds
    while (val <= max) {
      ticks.add(val);
      val = (val + step) as T;
    }
  }
  return ticks;
}

/// Get the step size for a linear axis based on the desired number of ticks.
NiceNumber getLinearTickStepSize<T extends num>(
  T min,
  T max,
  int minTicks,
  int maxTicks,
  bool encloseBounds,
) {
  int avgTicks = (minTicks + maxTicks) ~/ 2;
  NiceNumber stepSize = NiceNumber.fromDouble((max - min) / (avgTicks - 1), true);

  // If number of ticks is outside of the desired tick range,
  // then modify the step size until it is within the range.
  T range = (max - min) as T;
  int nTicks = (range / stepSize.value).ceil() + 1;
  if (encloseBounds) {
    nTicks += 2;
  }
  if (nTicks < minTicks) {
    stepSize =
        calculateLinearTickStepSize(nTicks, stepSize, range, encloseBounds, minTicks, ComparisonOperators.lt);
  } else if (nTicks > maxTicks) {
    stepSize =
        calculateLinearTickStepSize(nTicks, stepSize, range, encloseBounds, maxTicks, ComparisonOperators.gt);
  }
  return stepSize;
}

/// A linear mapping between data values and linear x-y values.
class LinearMapping extends Mapping {
  const LinearMapping();

  @override
  double map(num x) => x.toDouble();

  @override
  double inverse(double x) => x;

  @override
  AxisTicks ticksFromBounds({
    required Bounds<num> bounds,
    required int minTicks,
    required int maxTicks,
    required bool encloseBounds,
  }) {
    double min = bounds.min.toDouble();
    double max = bounds.max.toDouble();

    // What if max == min (e.g. there's only one point)
    if (min == max) {
      [min, max] = calculateCenteredBounds(max);
    }
    assert(max > min, "max must be greater than min");

    // Set the ticks based on the step size and whether or not the axis bounds should be included.
    NiceNumber stepSize = getLinearTickStepSize(min, max, minTicks, maxTicks, encloseBounds);
    double step = stepSize.value;

    List<double> ticks = [];
    if (encloseBounds) {
      // Make the ticks outside of the bounds
      min = (min / step).floor() * step;
      max = (max / step).ceil() * step;
      ticks = getLinearTicksFromStepSize(step, min, max, encloseBounds);
    } else {
      // Make the ticks inside the bounds
      min = (min / step).ceil() * step;
      max = (max / step).floor() * step;
      ticks = getLinearTicksFromStepSize(step, min, max, encloseBounds);
    }

    List<String> tickLabels = ticks.map((e) => e.toStringAsFixed(stepSize.power.abs())).toList();

    return AxisTicks(
      majorTicks: ticks,
      minorTicks: [],
      bounds: Bounds(ticks.first, ticks.last),
      tickLabels: tickLabels,
    );
  }

  /// Convert a [LinearMapping] to a JSON object.
  @override
  Map<String, dynamic> toJson() => {"type": "linear"};
}

/// A mapping between numerical strings and their unicode superscript values.
Map<String, String> mapIntToSuperscript = {
  "-": "⁻",
  "0": "⁰",
  "1": "¹",
  "2": "²",
  "3": "³",
  "4": "⁴",
  "5": "⁵",
  "6": "⁶",
  "7": "⁷",
  "8": "⁸",
  "9": "⁹",
};

/// Convert an integer to a unicode superscript string.
String intToSuperscript(int x) {
  String result = "";
  for (String digit in x.toString().split("")) {
    result += mapIntToSuperscript[digit]!;
  }
  return result;
}

/// Get the ticks for a logarithmic axis based on the bounds and the desired number of ticks.
AxisTicks getLogTicks({
  required Bounds<num> bounds,
  required int minTicks,
  required int maxTicks,
  required bool encloseBounds,
  required Mapping mapping,
  required double base,
  String? baseString,
}) {
  double min = bounds.min.toDouble();
  double max = bounds.max.toDouble();

  if (min == max) {
    [min, max] = calculateCenteredBounds(max);
  }
  assert(max > min, "max must be greater than min");

  // Map the bounds to the log scale
  int mappedMin;
  if (min > 0) {
    if (encloseBounds) {
      mappedMin = mapping.map(min).floor();
    } else {
      mappedMin = mapping.map(min).ceil();
    }
  } else {
    mappedMin = 0;
  }
  int mappedMax;
  if (encloseBounds) {
    mappedMax = mapping.map(max).ceil();
  } else {
    mappedMax = mapping.map(max).floor();
  }

  // Generate the major ticks and tick labels
  List<int> mappedTicks = List.generate(mappedMax - mappedMin + 1, (index) => (mappedMin + index));
  List<double> ticks = mappedTicks.isEmpty ? [] : mappedTicks.map((e) => e.toDouble()).toList();
  List<String> tickLabels = mappedTicks.map((e) => "${baseString ?? base}${intToSuperscript(e)}").toList();
  bounds = mappedTicks.isEmpty
      ? Bounds(min, max)
      : Bounds(
          math.min(min, math.pow(base, ticks.first)),
          math.max(max, math.pow(base, ticks.last)),
        );

  // Generate the minor ticks
  List<double> minorTicks = [];
  if (base == 10) {
    double boundedMin = math.min(mappedMin.toDouble(), mapping.map(min));
    double boundedMax = math.max(mappedMax.toDouble(), mapping.map(max));
    int tickStart = boundedMin.floor();
    int tickEnd = boundedMax.ceil();
    List<int> majorTicks = List.generate(tickEnd - tickStart + 1, (index) => (tickStart + index));
    for (int i = 0; i < majorTicks.length - 1; i++) {
      for (int j = 2; j < 10; j++) {
        double tick = majorTicks[i] + math.log(j) / math.ln10;
        if (tick > boundedMin && tick < boundedMax) {
          minorTicks.add(tick);
        }
      }
    }
  }

  return AxisTicks(
    bounds: bounds,
    majorTicks: ticks,
    minorTicks: minorTicks,
    tickLabels: tickLabels,
  );
}

/// A mapping between data values and natural logarithmic x-y values.
class LogMapping extends Mapping {
  const LogMapping();

  @override
  double map(double x) => math.log(x);

  @override
  double inverse(double x) => math.pow(math.e, x).toDouble();

  @override
  AxisTicks ticksFromBounds({
    required Bounds<num> bounds,
    required int minTicks,
    required int maxTicks,
    required bool encloseBounds,
  }) {
    return getLogTicks(
      bounds: bounds,
      minTicks: minTicks,
      maxTicks: maxTicks,
      encloseBounds: encloseBounds,
      mapping: this,
      baseString: "e",
      base: math.e,
    );
  }

  /// Convert a [LogMapping] to a JSON object.
  @override
  Map<String, dynamic> toJson() => {"type": "log"};
}

/// A mapping between data values and base 10 logarithmic x-y values.
class Log10Mapping extends Mapping {
  const Log10Mapping();
  @override
  double map(double x) => math.log(x) / math.ln10;

  @override
  double inverse(double x) => math.pow(10, x).toDouble();

  @override
  AxisTicks ticksFromBounds({
    required Bounds<num> bounds,
    required int minTicks,
    required int maxTicks,
    required bool encloseBounds,
  }) {
    return getLogTicks(
      bounds: bounds,
      minTicks: minTicks,
      maxTicks: maxTicks,
      encloseBounds: encloseBounds,
      mapping: this,
      base: 10,
    );
  }

  /// Convert a [Log10Mapping] to a JSON object.
  @override
  Map<String, dynamic> toJson() => {"type": "log10"};
}

List<double> calculateCenteredBounds(number) {
  final double radius = number / 2;
  return [number - radius, number + radius];
}

import 'dart:math' as math;

import 'package:rubin_chart/src/models/axes/ticks.dart';
import 'package:rubin_chart/src/utils/utils.dart';

class MappingError implements Exception {
  MappingError(this.message);

  String? message;

  @override
  String toString() => "$runtimeType:\n\t$message";
}

abstract class Mapping<T> {
  const Mapping();
  double map(T x);
  T inverse(double x);

  AxisTicks ticksFromBounds({
    required Bounds<num> bounds,
    required int minTicks,
    required int maxTicks,
    required bool encloseBounds,
  });
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
      print("Warning: Could not find a nice number for the ticks");
      return initialStepSize;
    }
  }
  return stepSize;
}

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

class LinearMapping extends Mapping<num> {
  const LinearMapping();

  @override
  double map(num x) => x.toDouble();

  @override
  num inverse(double x) => x;

  @override
  AxisTicks ticksFromBounds({
    required Bounds<num> bounds,
    required int minTicks,
    required int maxTicks,
    required bool encloseBounds,
  }) {
    double min = bounds.min.toDouble();
    double max = bounds.max.toDouble();

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
}

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

String intToSuperscript(int x) {
  String result = "";
  for (String digit in x.toString().split("")) {
    result += mapIntToSuperscript[digit]!;
  }
  return result;
}

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
  assert(max > min, "max must be greater than min");

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

  List<int> mappedTicks = List.generate(mappedMax - mappedMin + 1, (index) => (mappedMin + index));
  List<double> ticks = mappedTicks.isEmpty ? [] : mappedTicks.map((e) => e.toDouble()).toList();
  List<String> tickLabels = mappedTicks.map((e) => "${baseString ?? base}${intToSuperscript(e)}").toList();
  bounds = mappedTicks.isEmpty
      ? Bounds(min, max)
      : Bounds(
          math.min(min, math.pow(base, ticks.first)),
          math.max(max, math.pow(base, ticks.last)),
        );
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

class LogMapping extends Mapping<num> {
  const LogMapping();

  @override
  double map(num x) => math.log(x);

  @override
  num inverse(double x) => math.pow(math.e, x);

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
}

class Log10Mapping extends Mapping<num> {
  const Log10Mapping();
  @override
  double map(num x) => math.log(x) / math.ln10;

  @override
  num inverse(double x) => math.pow(10, x).toDouble();

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
}

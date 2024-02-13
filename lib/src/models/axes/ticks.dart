import "dart:math";
import "package:rubin_chart/src/utils/utils.dart";

/// A class for calculating nice numbers for ticks
class NiceNumber {
  // The power of 10 (ie. 10^power gives the [nearest10] value)
  final int power;
  // The factor of the [nearest10] value (ie. [factor] * [nearest10] gives the [value])
  final double factor;
  // The nearest 10th value (ie. [nearest10] * 10^power gives the [value])
  final double nearest10;

  NiceNumber(this.power, this.factor, this.nearest10);

  // The "nice" factors. All ticks will be one of the [factors] * a power of 10.
  static List<double> factors = [1, 2, 5, 10];
  // The number of possible factors.
  int get nFactors => factors.length;

  // Instantiate a [NiceNumber] from a double.
  static fromDouble(double x, bool round) {
    double logX = log(x) / ln10;
    int power = logX.floor();

    double nearest10 = power >= 0 ? pow(10, power).toDouble() : 1 / pow(10, -power).toDouble();
    // The factor will be between ~1 and ~10 (with some rounding errors)
    double factor = x / nearest10;

    if (round) {
      if (factor < 1.5) {
        factor = 1;
      } else if (factor < 3) {
        factor = 2;
      } else if (factor < 7) {
        factor = 5;
      } else {
        factor = 10;
      }
    } else {
      if (factor <= 1) {
        factor = 1;
      } else if (factor <= 2) {
        factor = 2;
      } else if (factor <= 5) {
        factor = 5;
      } else {
        factor = 10;
      }
    }
    return NiceNumber(power, factor, nearest10);
  }

  // The value of the [NiceNumber].
  double get value => factor * nearest10;

  // Modify the factor by [index] (ie. [index] = 1 will increase the factor by 1).
  // If the factor is modified to be outside of the [factors] list,
  // the [power] and [nearest10] will be modified accordingly.
  NiceNumber modifyFactor(int index) {
    if (index == 0) {
      return this;
    }

    int factorIndex = factors.indexOf(factor) + index;
    int newIndex = factorIndex % nFactors;
    int newPower = power + factorIndex ~/ nFactors;
    if (factorIndex < 0) {
      newPower -= 1;
    }

    double nearest10 = newPower >= 0 ? pow(10, newPower).toDouble() : 1 / pow(10, -newPower).toDouble();
    double newFactor = factors[newIndex];
    return NiceNumber(newPower, newFactor, nearest10);
  }

  @override
  String toString() => "$value: power=$power, factor=$factor, nearest10th=$nearest10";
}

/// Calculate the step size to generate ticks in [range].
/// If [encloseBounds] is true then ticks will be added to the
/// each side so that the bounds are included in the ticks
/// (usually used for initialization).
/// Otherwise the ticks will be inside or equal to the bounds.
NiceNumber calculateStepSize(
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

List<T> _ticksFromStepSize<T extends num>(T step, T min, T max, bool encloseBounds) {
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
    while (val < max) {
      ticks.add(val);
      val = (val + step) as T;
    }
  }
  return ticks;
}

NiceNumber _getStepSize<T extends num>(T min, T max, int minTicks, int maxTicks, bool encloseBounds) {
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
    stepSize = calculateStepSize(nTicks, stepSize, range, encloseBounds, minTicks, ComparisonOperators.lt);
  } else if (nTicks > maxTicks) {
    stepSize = calculateStepSize(nTicks, stepSize, range, encloseBounds, maxTicks, ComparisonOperators.gt);
  }
  return stepSize;
}

/// A class for calculating ticks for an axis.
class AxisTicks {
  /// The step size between ticks
  final NiceNumber stepSize;

  /// The ticks
  final List<double> ticks;

  /// The minimum value of the axis.
  final Bounds bounds;

  final List<String> tickLabels;

  AxisTicks._(this.stepSize, this.ticks, this.bounds, this.tickLabels);

  /// Generate tick marks for a range of numbers.
  static AxisTicks fromBounds(Bounds bounds, int minTicks, int maxTicks, bool encloseBounds) {
    double min = bounds.min.toDouble();
    double max = bounds.max.toDouble();

    assert(max > min, "max must be greater than min");

    // Set the ticks based on the step size and whether or not the axis bounds should be included.
    NiceNumber stepSize = _getStepSize(min, max, minTicks, maxTicks, encloseBounds);
    double step = stepSize.value;

    List<double> ticks = [];
    if (encloseBounds) {
      // Make the ticks outside of the bounds
      min = (min / step).floor() * step;
      max = (max / step).ceil() * step;
      ticks = _ticksFromStepSize(step, min, max, encloseBounds);
    } else {
      // Make the ticks inside the bounds
      min = (min / step).ceil() * step;
      max = (max / step).floor() * step;
      ticks = _ticksFromStepSize(step, min, max, encloseBounds);
    }

    List<String> tickLabels = ticks.map((e) => e.toStringAsFixed(stepSize.power.abs())).toList();

    return AxisTicks._(stepSize, ticks, Bounds(ticks.first, ticks.last), tickLabels);
  }

  static AxisTicks fromStrings(List<String> tickLabels) {
    List<double> ticks = List.generate(tickLabels.length, (index) => index.toDouble());
    return AxisTicks._(NiceNumber(0, 1, 1), ticks, Bounds(ticks.first, ticks.last), tickLabels);
  }

  static AxisTicks fromDateTime(DateTime min, DateTime max, int minTicks, int maxTicks, bool encloseBounds) {
    Duration timeDifference = max.difference(min);
    List<double> ticks = [];
    List<String> tickLabels = [];

    if (timeDifference < const Duration(microseconds: 1)) {
      throw "Invalid time range, $timeDifference < 1 micro scecond";
    } else if (timeDifference < const Duration(milliseconds: 1)) {
      NiceNumber stepSize = _getStepSize(min.microsecond, max.microsecond, minTicks, maxTicks, encloseBounds);
      int step = stepSize.value.toInt();
      List<int> micros = _ticksFromStepSize(step, min.microsecond, max.microsecond, encloseBounds);
      ticks = micros.map((e) => min.microsecondsSinceEpoch + e.toDouble()).toList();
      tickLabels = micros.map((e) => DateTime.fromMicrosecondsSinceEpoch(e).toString()).toList();
    } else if (timeDifference < Duration(minutes: minTicks)) {}

    throw UnimplementedError();
  }

  /// The number of ticks.
  int get length => ticks.length;

  @override
  String toString() => tickLabels.toString();
}

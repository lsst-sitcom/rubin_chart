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

import "dart:math";
import "package:rubin_chart/src/models/axes/mapping.dart";
import "package:rubin_chart/src/utils/utils.dart";

/// Convert a [DateTime] to a modified julian date (MJD).
double dateTimeToMjd(DateTime time) {
  int unixTime = time.microsecondsSinceEpoch;
  return (unixTime / 86400000000) + 40587;
}

/// Convert a modified julian date (MJD) to a [DateTime].
DateTime mjdToDateTime(num mjd) {
  int unixTime = ((mjd - 40587) * 86400000000).toInt();
  return DateTime.fromMicrosecondsSinceEpoch(unixTime);
}

/// Convert a [String] of the form 'year-month-day hours:minutes:seconds' into a [DateTime].
/// Note: seconds can be a double, which will extract the appropriate number of
/// milliseconds and microseconds.
DateTime dateFromString(String string) {
  String date;
  String time;
  if (string.contains(" ")) {
    List<String> split = string.split(" ");
    date = split[0];
    time = split[1];
  } else {
    date = string;
    time = "00:00:00";
  }

  List<String> dateSplit = date.split("-");
  List<String> timeSplit = time.split(":");

  int hours = timeSplit.isNotEmpty ? int.parse(timeSplit[0]) : 0;
  int minutes = timeSplit.length > 1 ? int.parse(timeSplit[1]) : 0;
  double secondsDouble = timeSplit.length > 2 ? double.parse(timeSplit[2]) : 0;
  int seconds = secondsDouble.floor();
  double milliDouble = (secondsDouble - seconds) * 1000;
  int milliSeconds = milliDouble.floor();
  double microDouble = (milliDouble - milliSeconds) * 1000;
  int microSeconds = microDouble.floor();

  return DateTime(
    int.parse(dateSplit[0]),
    int.parse(dateSplit[1]),
    int.parse(dateSplit[2]),
    hours,
    minutes,
    seconds,
    milliSeconds,
    microSeconds,
  );
}

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

/// A class for calculating ticks for an axis.
class AxisTicks {
  /// The step size between ticks
  /// The ticks
  final List<double> majorTicks;
  final List<double> minorTicks;

  /// The minimum value of the axis.
  final Bounds<num> bounds;

  final List<String?> tickLabels;

  AxisTicks({
    required this.majorTicks,
    required this.minorTicks,
    required this.bounds,
    required this.tickLabels,
  });

  /// Generate tick marks for a range of numbers.
  static AxisTicks fromBounds(
      Bounds<num> bounds, int minTicks, int maxTicks, bool encloseBounds, Mapping mapping) {
    return mapping.ticksFromBounds(
      bounds: bounds,
      minTicks: minTicks,
      maxTicks: maxTicks,
      encloseBounds: encloseBounds,
    );
  }

  /// Generate tick marks for a collection of strings.
  static AxisTicks fromStrings(List<String> tickLabels) {
    List<double> ticks = List.generate(tickLabels.length, (index) => index.toDouble());
    return AxisTicks(
      majorTicks: ticks,
      minorTicks: [],
      bounds: Bounds(ticks.first, ticks.last),
      tickLabels: tickLabels,
    );
  }

  /// Generate tick marks for a range of dates.
  /// This is currently not implemented, as I haven't had the
  /// time to make nice numbers for dates and this has
  /// been a low priority for us.
  static AxisTicks fromDateTime(DateTime min, DateTime max, int minTicks, int maxTicks, bool encloseBounds) {
    Duration timeDifference = max.difference(min);
    List<double> ticks = [];
    List<String> tickLabels = [];

    if (timeDifference < const Duration(microseconds: 1)) {
      throw "Invalid time range, $timeDifference < 1 micro scecond";
    } else if (timeDifference < const Duration(milliseconds: 1)) {
      NiceNumber stepSize =
          getLinearTickStepSize(min.microsecond, max.microsecond, minTicks, maxTicks, encloseBounds);
      int step = stepSize.value.toInt();
      List<int> micros = getLinearTicksFromStepSize(step, min.microsecond, max.microsecond, encloseBounds);
      ticks = micros.map((e) => min.microsecondsSinceEpoch + e.toDouble()).toList();
      tickLabels = micros.map((e) => DateTime.fromMicrosecondsSinceEpoch(e).toString()).toList();
    } else if (timeDifference < Duration(minutes: minTicks)) {}

    throw UnimplementedError();
  }

  /// The number of ticks.
  int get length => majorTicks.length;

  @override
  String toString() => tickLabels.toString();
}

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

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

/// Alias for [ListEquality.equals].
Function listEq = const ListEquality().equals;

/// Alias for [DeepCollectionEquality.equals].
Function deepEq = const DeepCollectionEquality().equals;

/// listEquality
/// Get the max or min of a list
T? listEquality<T extends num>(List<T> list, String op) {
  assert(["max", "min"].contains(op));
  if (list.isEmpty) {
    return null;
  }
  T result = list[0];
  for (T x in list) {
    if (op == "max" && x > result) {
      result = x;
    } else if (op == "min" && x < result) {
      result = x;
    }
  }
  return result;
}

/// Returns the maximum value in a list of numbers.
T? listMax<T extends num>(List<T> list) => listEquality(list, "max");

/// Returns the minimum value in a list of numbers.
T? listMin<T extends num>(List<T> list) => listEquality(list, "min");

/// Sort a map by its keys and return the list of values
List<V> sortMapByKey<K, V>(Map<K, V> input) {
  List<K> sorted = input.keys.toList();
  sorted.sort();
  return sorted.map((K key) => input[key]!).toList();
}

/// Get the size of a block of text
Size getTextSize(TextStyle style, {String text = "\u{1F600}"}) {
  TextSpan textSpan = TextSpan(text: text, style: style);
  TextPainter painter = TextPainter(
    text: textSpan,
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout();

  return painter.size;
}

/// Maximum value in an [Iterable].
T? iterableMax<T extends num>(Iterable<T> iterable) {
  if (iterable.isEmpty) {
    return null;
  }
  T result = iterable.first;
  for (T item in iterable) {
    result = math.max(item, result);
  }
  return result;
}

/// Minimum value in an [Iterable].
T? iterableMin<T extends num>(Iterable<T> iterable) {
  if (iterable.isEmpty) {
    return null;
  }
  T result = iterable.first;
  for (T item in iterable) {
    result = math.min(item, result);
  }
  return result;
}

/// Remove all characters matching [char] to the right of the [String] [str].
String trimStringRight(String str, String char) {
  for (int i = str.length - 1; i >= 0; i--) {
    if (str[i] != char) {
      return str.substring(0, i + 1);
    }
  }
  return str;
}

/// Remove all characters matching [char] to the left of the [String] [str].
String trimStringLeft(String str, String char) {
  for (int i = 0; i < str.length; i++) {
    if (str[i] != char) {
      return str.substring(i);
    }
  }
  return str;
}

/// The bounds of an array ([List]) for any comparable type.
class Bounds<T extends Comparable> {
  /// Minimum bound.
  final T min;

  /// Maximum bound.
  final T max;

  const Bounds(this.min, this.max);

  /// Intersection of two bounds.
  Bounds<T> operator &(Bounds<T> other) {
    T min = this.min.compareTo(other.min) > 0 ? this.min : other.min;
    T max = this.max.compareTo(other.max) < 0 ? this.max : other.max;
    return Bounds<T>(min, max);
  }

  /// Union of two bounds.
  Bounds<T> operator |(Bounds<T> other) {
    T min = this.min.compareTo(other.min) < 0 ? this.min : other.min;
    T max = this.max.compareTo(other.max) > 0 ? this.max : other.max;
    return Bounds<T>(min, max);
  }

  /// Check if a value is within the bounds.
  bool contains(T value, {bool inclusive = true}) {
    if (inclusive) {
      return value.compareTo(min) >= 0 && value.compareTo(max) <= 0;
    } else {
      return value.compareTo(min) > 0 && value.compareTo(max) < 0;
    }
  }

  /// Check if another bounds is within the bounds.
  bool containsBounds(Bounds<T> other, {bool inclusive = true}) {
    return contains(other.min, inclusive: inclusive) && contains(other.max, inclusive: inclusive);
  }

  /// Check if these bounds are contained in another set of bounds.
  bool containedInBounds(Bounds<T> other, {bool inclusive = true}) {
    return other.containsBounds(this, inclusive: inclusive);
  }

  @override
  String toString() => "Bounds<$min-$max>";

  @override
  bool operator ==(Object other) {
    if (other is Bounds<T>) {
      return min == other.min && max == other.max;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(min, max);

  /// Factory method to create Bounds from a list of Comparable elements.
  static Bounds<T> fromList<T extends Comparable>(List<T> data) {
    if (data.isEmpty) {
      throw ArgumentError("data cannot be empty");
    }
    T min = data.first;
    T max = data.first;
    for (T x in data) {
      if (x.compareTo(min) < 0) min = x;
      if (x.compareTo(max) > 0) max = x;
    }
    return Bounds<T>(min, max);
  }

  /// Convert the Bounds object to a JSON representation.
  Map<String, dynamic> toJson() {
    return {
      'min': min.toString(),
      'max': max.toString(),
      'type': T.toString(),
    };
  }

  /// Create a Bounds object from a JSON representation.
  static Bounds<T> fromJson<T extends Comparable>(Map<String, dynamic> json) {
    // This function needs to handle different Comparable types
    switch (json['type']) {
      case 'int':
        return Bounds<int>(
          int.parse(json['min'] as String),
          int.parse(json['max'] as String),
        ) as Bounds<T>;
      case 'double':
        return Bounds<double>(
          double.parse(json['min'] as String),
          double.parse(json['max'] as String),
        ) as Bounds<T>;
      case 'String':
        return Bounds<String>(
          json['min'] as String,
          json['max'] as String,
        ) as Bounds<T>;
      case 'DateTime':
        return Bounds<DateTime>(
          DateTime.parse(json['min'] as String),
          DateTime.parse(json['max'] as String),
        ) as Bounds<T>;
      default:
        throw ArgumentError('Unsupported type: ${json['type']}');
    }
  }
}

/// Different comparison operators.
enum ComparisonOperators {
  /// Equal to.
  eq,

  /// Not equal to.
  ne,

  /// Less than.
  lt,

  /// Greater than.
  gt,

  /// Less than or equal to.
  le,

  /// Greater than or equal to.
  ge,
}

/// A function that compares two values.
bool compare<T extends Comparable<T>>(T x, T y, ComparisonOperators op) {
  switch (op) {
    case ComparisonOperators.eq:
      return x == y;
    case ComparisonOperators.ne:
      return x != y;
    case ComparisonOperators.lt:
      return x.compareTo(y) < 0;
    case ComparisonOperators.gt:
      return x.compareTo(y) > 0;
    case ComparisonOperators.le:
      return x.compareTo(y) <= 0;
    case ComparisonOperators.ge:
      return x.compareTo(y) >= 0;
  }
}

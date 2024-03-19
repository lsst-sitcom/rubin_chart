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

T? listMax<T extends num>(List<T> list) => listEquality(list, "max");
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
}

enum ComparisonOperators {
  eq,
  ne,
  lt,
  gt,
  le,
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

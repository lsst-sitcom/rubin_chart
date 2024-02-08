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

/// The bounds of a numerical array ([List]).
class Bounds {
  /// Minimum bound.
  final num min;

  /// Maximum bound.
  final num max;

  const Bounds(this.min, this.max);

  /// Intersection of two bounds.
  Bounds operator &(Bounds other) {
    num min = this.min;
    num max = this.max;
    if (other.min > min) {
      min = other.min;
    }
    if (other.max < max) {
      max = other.max;
    }
    return Bounds(min, max);
  }

  /// Union of two bounds.
  Bounds operator |(Bounds other) {
    num min = this.min;
    num max = this.max;
    if (other.min < min) {
      min = other.min;
    }
    if (other.max > max) {
      max = other.max;
    }
    return Bounds(min, max);
  }

  /// Range of the bounded data.
  num get range => max - min;

  @override
  String toString() => "Bounds<$min-$max>";
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

import 'dart:math' as math;


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
}


class LinearMapping extends Mapping<num> {
  const LinearMapping();

  @override
  double map(num x) => x.toDouble();

  @override
  num inverse(double x) => x;
}


class LogMapping extends Mapping<num> {
  const LogMapping();

  @override
  double map(num x) => math.log(x);

  @override
  num inverse(double x) => math.pow(math.e, x);
}


class Log10Mapping extends Mapping<num> {
  const Log10Mapping();
  @override
  double map(num x) => math.log(x)/math.ln10;

  @override
  num inverse(double x) => math.pow(10, x).toDouble();
}


class ExpMapping extends Mapping<num> {
  const ExpMapping();

  @override
  double map(num x) => math.pow(math.e, x).toDouble();

  @override
  num inverse(double x) => math.log(x);
}


class Exp10Mapping extends Mapping<num> {
  const Exp10Mapping();

  @override
  double map(num x) => math.pow(10, x).toDouble();

  @override
  num inverse(double x) => math.log(x)/math.ln10;
}

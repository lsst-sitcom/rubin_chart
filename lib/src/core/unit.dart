import 'dart:math' as math;

enum BaseUnit {
  time("time", "t"),
  length("length", "l"),
  mass("mass", "m"),
  current("current", "i"),
  temperature("temperature", "T"),
  number("number", "n"),
  intensity("intensity", "Iv"),
  angle("angle", "\u2220"),
  date("date", "date"),
  string("string", "str"),
  magnitude("magnitude", "mag");

  final String fullName;
  final String symbol;

  const BaseUnit(this.fullName, this.symbol);
}


enum SiUnitPrefix {
  Q("quetta", "Q", 30),
  R("ronna", "R", 27),
  Y("yotta", "Y", 24),
  Z("zetta", "Z", 21),
  E("exa", "E", 18),
  P("peta", "P", 15),
  T("tera", "T", 12),
  G("giga", "G", 9),
  M("mega", "M", 6),
  k("kilo", "k", 3),
  h("hecto", "h", 2),
  da("deka", "da", 1),
  d("deci", "d", -1),
  c("centi", "c", -2),
  m("milli", "m", -3),
  mu("micro", "\u03BC", -6),
  n("nano", "n", -9),
  p("pico", "p", -12),
  f("femto", "f", -15),
  a("atto", "a", -18),
  z("zepta", "z", -21),
  y("yocto", "y", -24),
  r("ronto", "r", -27),
  q("quecto", "q", -30);

  const SiUnitPrefix(this.fullName, this.symbol, this.order);

  final String fullName;
  final String symbol;
  final int order;
}


const Map<String, Unit> siBaseUnits = {
  "s": SiUnit("second", "s", BaseUnit.time, 1),
};


const Map<String, Unit> angles = {
  "deg": Unit("degrees", "deg", BaseUnit.angle, 1),
  "rad": Unit("radians", "rad", BaseUnit.angle, 1/degToRadians),
};


class Unit {
  final String name;
  final String symbol;
  final BaseUnit base;
  final num _factor;

  const Unit(this.name, this.symbol, this.base, num factor): _factor = factor;

  num get factor => _factor;

  @override
  String toString() => symbol;

  // SI base units
  static Unit get s => const SiUnit("second", "s", BaseUnit.time, 1);

  // Angles
  static Unit get deg => const Unit("degrees", "deg", BaseUnit.angle, 1);
  static Unit get rad => const Unit("radians", "rad", BaseUnit.angle, 1/degToRadians);

  /// String (not really a unit, but used for non-numerical columns)
  static Unit get string => const Unit("string", "str", BaseUnit.string, 1);

  /// Date/time (not really a unit, but used for [DateTime] columns).
  static Unit get date => const Unit("date", "date", BaseUnit.date, 1);

  /// Number count
  static Unit get number => const Unit("number", "number", BaseUnit.number, 1);

  /// Magnitude
  static Unit get mag => const Unit("magnitude", "mag", BaseUnit.magnitude, 1);
}


class SiUnit extends Unit {
  final SiUnitPrefix? prefix;

  const SiUnit(
    super.name,
    super.symbol,
    super.base,
    super.factor,
    [this.prefix]
  );

  @override
  num get factor => prefix == null
    ? _factor
    : _factor * math.pow(10, prefix!.order);
}


class UnitConversionError implements Exception{
  UnitConversionError(this.message);

  String? message;

  @override
  String toString() => "$runtimeType:\n\t$message";
}


/// Get multiplication factor by unit
num convertUnit(Unit? from, Unit? to){
  if(from == null){
    if(to == null){
      return 1;
    }
    throw UnitConversionError("Cannot convert from dimensionless quantity into $to");
  } else if(to == null){
    throw UnitConversionError("Cannot convert from $from into a dimensionless quantity");
  }

  if(from != to){
    throw UnitConversionError("Cannot covert $from into $to");
  }
  if(from.base != to.base){
    throw UnitConversionError("Expected bases to match, got ${from.base}, ${to.base}");
  }

  return to.factor / from.factor;
}

const degToRadians = math.pi/180;


class Quantity {
  final Unit? unit;
  final num value;

  const Quantity(this.value, this.unit);

  Quantity to(Unit unit){
    return Quantity(value * convertUnit(this.unit!, unit), unit);
  }

  Quantity operator -() => Quantity(-value, unit);
  Quantity operator *(Quantity other) => Quantity(value * convertUnit(other.unit, unit), unit);
  Quantity operator /(Quantity other) => Quantity(value / convertUnit(other.unit, unit), unit);
  Quantity operator +(Quantity other) => Quantity(value + convertUnit(other.unit, unit), unit);
  Quantity operator -(Quantity other) => Quantity(value - convertUnit(other.unit, unit), unit);
  bool operator >(Quantity other) => value > convertUnit(other.unit, unit);
  bool operator >=(Quantity other) => value >= convertUnit(other.unit, unit);
  bool operator <(Quantity other) => value < convertUnit(other.unit, unit);
  bool operator <=(Quantity other) => value <= convertUnit(other.unit, unit);
}

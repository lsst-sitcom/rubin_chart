import 'package:flutter_test/flutter_test.dart';
import 'package:rubin_chart/rubin_chart.dart';

void main() {
  test('adds one to input values', () {});
  test('data contains only single point', () {
    const bounds = Bounds(30, 30);
    AxisTicks linTicks = AxisTicks.fromBounds(bounds as Bounds<num>, 7, 15, false, const LinearMapping());
    print(linTicks);
    assert(linTicks.length > 0);
    AxisTicks logTicks = AxisTicks.fromBounds(bounds as Bounds<num>, 7, 15, false, const LogMapping());
    print(logTicks);
    assert(logTicks.length > 0);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/services/distance.dart';

void main() {
  test('distance between identical points is zero', () {
    expect(distanceKm(-1.286389, 36.817223, -1.286389, 36.817223), closeTo(0, 0.0001));
  });

  test('distance between Nairobi CBD and JKIA is roughly correct', () {
    // Nairobi CBD ~ -1.2864, 36.8172 ; JKIA ~ -1.3192, 36.9278
    final km = distanceKm(-1.2864, 36.8172, -1.3192, 36.9278);
    expect(km, greaterThan(10));
    expect(km, lessThan(15));
  });
}

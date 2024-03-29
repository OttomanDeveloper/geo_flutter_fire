import 'package:flutter_test/flutter_test.dart';
import 'package:geo_flutter_fire/geo_flutter_fire.dart';
import 'package:geo_flutter_fire/src/utils/arrays.dart';
import 'package:geo_flutter_fire/src/utils/math.dart';

void main() {
  test('whereNotNull should remove correct elements', () {
    final param = [
      1,
      2,
      null,
      null,
      3,
      null,
      3,
    ];

    final expected = [1, 2, 3, 3];

    final got = param.whereNotNull();
    expect(expected, got);
  });

  test('distance test', () {
    expect(
      MathUtils.kmDistance(
        const Coordinates(90, 0),
        const Coordinates(0, 90),
      ),
      closeTo(10001 /*km*/, 2),
    );
  });
}

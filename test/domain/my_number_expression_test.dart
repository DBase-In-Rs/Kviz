import 'package:flutter_test/flutter_test.dart';
import 'package:kviz/domain/my_number_expression.dart';

void main() {
  group('MyNumberExpressionEvaluator', () {
    test('evaluates expression with offered numbers', () {
      final result = MyNumberExpressionEvaluator.evaluate('(100 + 50) * 3', [
        100,
        50,
        9,
        7,
        6,
        3,
      ]);

      expect(result.value, 450);
      expect(result.usedNumbers, [100, 50, 3]);
      expect(result.distanceTo(452), 2);
    });

    test('rejects numbers that were not offered', () {
      expect(
        () => MyNumberExpressionEvaluator.evaluate('100 + 100', [100, 50]),
        throwsA(isA<MyNumberExpressionException>()),
      );
    });

    test('rejects non-integer division', () {
      expect(
        () => MyNumberExpressionEvaluator.evaluate('7 / 2', [7, 2]),
        throwsA(isA<MyNumberExpressionException>()),
      );
    });
  });
}

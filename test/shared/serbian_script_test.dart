import 'package:flutter_test/flutter_test.dart';
import 'package:kviz/shared/utils.dart';

void main() {
  group('Serbian script helpers', () {
    test('transcribes Serbian Latin labels and text to Cyrillic', () {
      expect(toSerbianCyrillic('Kolona B'), 'Колона Б');
      expect(toSerbianCyrillic('Kolona V'), 'Колона В');
      expect(toSerbianCyrillic('Konačno rešenje'), 'Коначно решење');
      expect(
        toSerbianCyrillic('Džep, Ljubav, Njiva, Đak'),
        'Џеп, Љубав, Њива, Ђак',
      );
    });

    test('transcribes Serbian Cyrillic text back to Latin', () {
      expect(toSerbianLatin('Колона Б'), 'Kolona B');
      expect(toSerbianLatin('Колона В'), 'Kolona V');
      expect(toSerbianLatin('Коначно решење'), 'Konačno rešenje');
      expect(toSerbianLatin('ЉУБАВ'), 'LJUBAV');
    });

    test('normalizes association target labels for current script', () {
      expect(srAssociationTargetLabel(true, 'B'), 'Б');
      expect(srAssociationTargetLabel(true, 'V'), 'В');
      expect(srAssociationTargetLabel(true, 'final'), 'Коначно');
      expect(srAssociationTargetLabel(false, 'Коначно'), 'Konačno');
    });

    test('keeps explicit manual translations unchanged', () {
      expect(tr(true, 'Google Play', 'Google Play'), 'Google Play');
      expect(tr(true, 'Kolona V'), 'Колона В');
      expect(tr(false, 'Колона В'), 'Kolona V');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wami/core/utils/phone.dart';
import 'package:wami/features/auth/domain/usecases/auth_usecases.dart';

void main() {
  group('BeninPhone', () {
    test('met au format international', () {
      expect(BeninPhone.toInternational('01 97 12 34 56'), '+2290197123456');
      expect(BeninPhone.toInternational('0197123456'), '+2290197123456');
    });

    test('accepte un indicatif déjà tapé', () {
      expect(BeninPhone.toInternational('+229 01 97 12 34 56'), '+2290197123456');
      expect(BeninPhone.toInternational('00229 0197123456'), '+2290197123456');
    });

    test('refuse un numéro incomplet ou trop long', () {
      expect(BeninPhone.toInternational('97 12 34'), isNull);
      expect(BeninPhone.toInternational('019712345678'), isNull);
    });

    test('affiche par paires', () => expect(BeninPhone.display('+2290197123456'), '01 97 12 34 56'));
  });

  group('PasswordPolicy', () {
    test('suit les règles du back', () {
      expect(PasswordPolicy.check('Court1'), isNotNull);
      expect(PasswordPolicy.check('sansmajuscule1'), isNotNull);
      expect(PasswordPolicy.check('SANSMINUSCULE1'), isNotNull);
      expect(PasswordPolicy.check('SansChiffreIci'), isNotNull);
      expect(PasswordPolicy.check('Motdepasse1'), isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wami/core/auth/auth_session.dart';
import 'package:wami/core/auth/current_session.dart';
import 'package:wami/core/error/exceptions.dart';
import 'package:wami/features/account/data/datasources/account_data_sources.dart';
import 'package:wami/features/account/domain/entities/user_profile.dart';

import '../../support/stub_server.dart';

Map<String, dynamic> _profile({
  String first = 'Awa',
  String last = 'Dossou',
  String? email,
  String phone = '+2290197123456',
}) =>
    {
      'success': true,
      'data': {'firstName': first, 'lastName': last, 'phoneNumber': phone, if (email != null) 'email': email},
    };

void main() {
  late StubServer server;
  late AccountApiDataSource account;

  setUp(() {
    server = StubServer();
    final session = CurrentSession()
      ..set(
        const AuthSession(
          token: 't',
          userId: 'u1',
          passengerId: 'p',
          walletId: 'w',
          phone: '+2290197123456',
          firstName: 'Awa',
          lastName: 'Dossou',
        ),
      );
    account = AccountApiDataSource(server.client(session: session), session);
  });

  test('profil : identité du back, pas de niveau ni de note inventés', () async {
    server.on('GET /api/passengers/profile', _profile(email: 'awa@exemple.bj'));
    final p = await account.profile();
    expect(p.fullName, 'Awa Dossou');
    expect(p.phone, '+2290197123456');
    expect(p.email, 'awa@exemple.bj');
    expect(p.tier, isEmpty);
    expect(p.rating, 0);
  });

  test('modification : seuls les champs changés sont envoyés', () async {
    server
      ..on('GET /api/passengers/profile', _profile())
      ..on('PATCH /api/users/u1/name', {'success': true})
      ..on(
        'POST /api/users/u1/add-email',
        {'success': false, 'error': 'User already has an email. Use updateEmail to change it.'},
        status: 409,
      )
      ..on('PATCH /api/users/u1/email', {'success': true});
    final current = await account.profile();

    await account.updateProfile(
      UserProfile(
        fullName: 'Awa Koffi Dossou',
        phone: current.phone,
        email: 'awa@exemple.bj',
        tier: '',
        rating: 0,
      ),
    );

    expect(server.last('PATCH /api/users/u1/name')!.data, {'firstName': 'Awa', 'lastName': 'Koffi Dossou'});
    expect(server.last('PATCH /api/users/u1/email')!.data, {'newEmail': 'awa@exemple.bj'});
    expect(server.count('PATCH /api/users/u1/phone'), 0);
  });

  test('lieux et contact d’urgence gardés par l’application', () async {
    server.on('GET /api/passengers/profile', _profile());
    final current = await account.profile();
    final saved = await account.updateProfile(
      UserProfile(
        fullName: current.fullName,
        phone: current.phone,
        email: '',
        tier: '',
        rating: 0,
        savedPlaces: const [SavedPlace(label: 'Maison', address: 'Fidjrossè')],
        emergencyContact: 'Koffi',
      ),
    );
    expect(saved.savedPlaces.single.label, 'Maison');
    expect(saved.emergencyContact, 'Koffi');
    expect(server.count('PATCH /api/users/u1/name'), 0);
  });

  group('e-mail, civilité, adresse, vérification', () {
    Map<String, dynamic> profile({String? gender, bool emailVerified = false, bool phoneVerified = true}) => {
          'success': true,
          'data': {
            'firstName': 'Awa',
            'lastName': 'Dossou',
            'phoneNumber': '+2290197123456',
            if (gender != null) 'gender': gender,
            'isEmailVerified': emailVerified,
            'isPhoneVerified': phoneVerified,
          },
        };

    test('profil : civilité et statuts de vérification lus', () async {
      server.on('GET /api/passengers/profile', profile(gender: 'FEMALE', phoneVerified: false));
      final p = await account.profile();
      expect(p.gender, Gender.female);
      expect(p.phoneVerified, isFalse);
      expect(p.emailVerified, isFalse);
    });

    test('nouvel e-mail : ajout, vérifié à part (le profil du back ne renvoie pas l’e-mail)', () async {
      server
        ..on('GET /api/passengers/profile', profile())
        ..on('POST /api/users/u1/add-email', {
          'success': true,
          'data': {'email': 'awa@exemple.bj', 'isEmailVerified': false},
        });
      final current = await account.profile();
      final saved = await account.updateProfile(current.copyWith(email: 'awa@exemple.bj'));
      expect(server.last('POST /api/users/u1/add-email')!.data, {'email': 'awa@exemple.bj'});
      expect(server.count('PATCH /api/users/u1/email'), 0);
      expect(saved.email, 'awa@exemple.bj', reason: 'gardé pour la session puisque le back ne le renvoie pas');
    });

    test('civilité envoyée puis profil relu', () async {
      server
        ..on('GET /api/passengers/profile', profile(gender: 'MALE'))
        ..on('PATCH /api/users/u1/gender', {'success': true});
      final p = await account.setGender(Gender.male);
      expect(server.last('PATCH /api/users/u1/gender')!.data, {'gender': 'MALE'});
      expect(p.gender, Gender.male);
    });

    test('adresse : champs vides non envoyés, adresse gardée pour la session', () async {
      server
        ..on('GET /api/passengers/profile', profile())
        ..on('PATCH /api/users/u1/address', {'success': true});
      final p = await account.setAddress(const PostalAddress(city: 'Cotonou', quarter: 'Akpakpa', street: ' '));
      expect(server.last('PATCH /api/users/u1/address')!.data, {
        'address': {'city': 'Cotonou', 'quarter': 'Akpakpa'},
      });
      expect(p.address?.summary, 'Akpakpa, Cotonou');
    });

    test('vérification : bonne route selon le contact, code refusé en français', () async {
      server
        ..on('GET /api/passengers/profile', profile(emailVerified: true))
        ..on('POST /api/users/u1/verify-email', {'success': true})
        ..on(
          'POST /api/users/u1/verify-phone',
          {'success': false, 'error': 'Code de vérification invalide ou expiré.'},
          status: 400,
        );
      final p = await account.verify(VerificationKind.email, '123456');
      expect(server.last('POST /api/users/u1/verify-email')!.data, {'code': '123456'});
      expect(p.emailVerified, isTrue);
      await expectLater(
        account.verify(VerificationKind.phone, '000000'),
        throwsA(
          isA<BusinessRuleException>()
              .having((e) => e.message, 'message', 'Code invalide ou expiré. Demandez un nouveau code.'),
        ),
      );
    });

    test('renvoi des codes', () async {
      server.on('POST /api/users/u1/resend-verification', {'success': true});
      await account.resendVerification();
      expect(server.count('POST /api/users/u1/resend-verification'), 1);
    });
  });
}

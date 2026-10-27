import 'package:flutter_test/flutter_test.dart';
import 'package:wami/core/auth/auth_session.dart';
import 'package:wami/core/auth/current_session.dart';
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
}

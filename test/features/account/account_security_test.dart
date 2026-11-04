import 'package:flutter_test/flutter_test.dart';
import 'package:wami/core/auth/auth_session.dart';
import 'package:wami/core/auth/current_session.dart';
import 'package:wami/core/error/exceptions.dart';
import 'package:wami/core/error/failures.dart';
import 'package:wami/core/utils/result.dart';
import 'package:wami/features/account/data/datasources/account_data_sources.dart';
import 'package:wami/features/account/domain/repositories/account_repository.dart';
import 'package:wami/features/account/domain/usecases/account_usecases.dart';

import '../../support/stub_server.dart';

const _session = AuthSession(
  token: 't',
  userId: 'u1',
  passengerId: 'p',
  walletId: 'w',
  phone: '+2290197123456',
  firstName: 'Awa',
  lastName: 'Dossou',
);

class _Repo implements AccountRepository {
  int changed = 0;
  int deleted = 0;

  @override
  Future<Result<void>> changePassword({required String currentPassword, required String newPassword}) async {
    changed++;
    return const Ok(null);
  }

  @override
  Future<Result<void>> deleteAccount(String password) async {
    deleted++;
    return const Ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('règles', () {
    late _Repo repo;
    late ChangePassword change;

    setUp(() {
      repo = _Repo();
      change = ChangePassword(repo);
    });

    Future<Failure?> failureOf(String current, String next, String confirmation) async {
      final r = await change(ChangePasswordParams(current: current, next: next, confirmation: confirmation));
      return switch (r) {
        Err(:final failure) => failure,
        Ok() => null,
      };
    }

    test(
      'mot de passe actuel obligatoire',
      () async => expect(await failureOf('', 'Nouveau2pass', 'Nouveau2pass'), isNotNull),
    );
    test(
      'nouveau mot de passe trop faible',
      () async => expect(await failureOf('Ancien1pass', 'faible', 'faible'), isNotNull),
    );
    test(
      'confirmation différente',
      () async => expect(await failureOf('Ancien1pass', 'Nouveau2pass', 'Autre3pass'), isNotNull),
    );
    test(
      'identique à l’actuel',
      () async => expect(await failureOf('Ancien1pass', 'Ancien1pass', 'Ancien1pass'), isNotNull),
    );

    test('valide : le back est appelé', () async {
      expect(await failureOf('Ancien1pass', 'Nouveau2pass', 'Nouveau2pass'), isNull);
      expect(repo.changed, 1);
    });

    test('refus sans appel du back', () async {
      await failureOf('Ancien1pass', 'faible', 'faible');
      expect(repo.changed, 0);
    });

    test('suppression : mot de passe obligatoire', () async {
      final r = await DeleteAccount(repo)('');
      expect(r, isA<Err<void>>());
      expect(repo.deleted, 0);
    });
  });

  group('source de données', () {
    late StubServer server;
    late CurrentSession session;
    late AccountApiDataSource account;
    late int expired;
    late int logouts;

    setUp(() {
      server = StubServer();
      session = CurrentSession()..set(_session);
      expired = 0;
      logouts = 0;
      session.onExpired.listen((_) => expired++);
      session.onLogoutRequested.listen((_) => logouts++);
      account = AccountApiDataSource(server.client(session: session), session);
    });

    test('changement de mot de passe : corps envoyé', () async {
      server.on('PUT /api/passengers/password', {'success': true});
      await account.changePassword('Ancien1pass', 'Nouveau2pass');
      expect(server.last('PUT /api/passengers/password')!.data, {
        'currentPassword': 'Ancien1pass',
        'newPassword': 'Nouveau2pass',
      });
    });

    test('mauvais mot de passe actuel : message clair et la session reste ouverte', () async {
      server.on(
        'PUT /api/passengers/password',
        {
          'success': false,
          'error': {'message': 'Current password is incorrect', 'code': 'UNAUTHORIZED'},
        },
        status: 401,
      );
      await expectLater(
        account.changePassword('Mauvais1pass', 'Nouveau2pass'),
        throwsA(isA<BusinessRuleException>().having((e) => e.message, 'message', 'Mot de passe actuel incorrect.')),
      );
      await Future<void>.delayed(Duration.zero);
      expect(expired, 0);
    });

    test('un 401 ordinaire ferme la session', () async {
      server.on(
        'GET /api/passengers/profile',
        {
          'success': false,
          'error': {'message': 'Session expirée', 'code': 'SESSION_EXPIRED'},
        },
        status: 401,
      );
      await expectLater(account.profile(), throwsA(isA<UnauthorizedException>()));
      await Future<void>.delayed(Duration.zero);
      expect(expired, 1);
    });

    test('suppression : mot de passe envoyé puis déconnexion demandée', () async {
      server.on('DELETE /api/passengers/profile', {'success': true});
      await account.deleteAccount('Motdepasse1');
      await Future<void>.delayed(Duration.zero);
      expect(server.last('DELETE /api/passengers/profile')!.data, {'password': 'Motdepasse1'});
      expect(logouts, 1);
    });

    test('suppression : le back plante après avoir supprimé le profil, l’app le constate', () async {
      server
        ..on(
          'DELETE /api/passengers/profile',
          {
            'success': false,
            'error': {
              'message': 'An unexpected error occurred while deleting profile',
              'code': 'INTERNAL_SERVER_ERROR',
            },
          },
          status: 500,
        )
        ..on(
          'GET /api/passengers/profile',
          {
            'success': false,
            'error': {'message': 'Passenger profile not found', 'code': 'NOT_FOUND'},
          },
          status: 404,
        );
      await account.deleteAccount('Motdepasse1');
      await Future<void>.delayed(Duration.zero);
      expect(logouts, 1);
    });

    test('suppression : vraie panne du serveur, le compte existe encore', () async {
      server
        ..on('DELETE /api/passengers/profile', {'success': false, 'error': 'boom'}, status: 500)
        ..on('GET /api/passengers/profile', {
          'success': true,
          'data': {'firstName': 'Awa', 'lastName': 'Dossou', 'phoneNumber': '+2290197123456'},
        });
      await expectLater(account.deleteAccount('Motdepasse1'), throwsA(isA<ServerException>()));
      await Future<void>.delayed(Duration.zero);
      expect(logouts, 0);
    });

    test('suppression refusée : pas de déconnexion', () async {
      server.on(
        'DELETE /api/passengers/profile',
        {
          'success': false,
          'error': {'message': 'Invalid password', 'code': 'UNAUTHORIZED'},
        },
        status: 401,
      );
      await expectLater(account.deleteAccount('Mauvais1pass'), throwsA(isA<BusinessRuleException>()));
      await Future<void>.delayed(Duration.zero);
      expect(logouts, 0);
      expect(expired, 0);
    });
  });
}

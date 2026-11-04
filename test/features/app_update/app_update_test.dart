import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wami/app.dart';
import 'package:wami/app/di/injection.dart';
import 'package:wami/core/app_info/app_info.dart';
import 'package:wami/core/auth/auth_session.dart';
import 'package:wami/core/auth/session_store.dart';
import 'package:wami/core/config/app_config.dart';
import 'package:wami/core/di/service_locator.dart';
import 'package:wami/core/error/exceptions.dart';
import 'package:wami/core/error/failures.dart';
import 'package:wami/core/system/url_opener.dart';
import 'package:wami/core/utils/result.dart';
import 'package:wami/features/app_update/data/datasources/app_update_data_sources.dart';
import 'package:wami/features/app_update/domain/entities/app_version_status.dart';
import 'package:wami/features/app_update/domain/repositories/app_update_repository.dart';
import 'package:wami/features/app_update/domain/usecases/check_app_version.dart';
import 'package:wami/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:wami/features/app_update/presentation/cubit/update_cubit.dart';

import '../../support/stub_server.dart';

AppVersionStatus _status({
  bool available = false,
  bool force = false,
  DateTime? after,
  String latest = '1.2.0',
  String url = 'https://play.google.com/store/apps/details?id=bj.wami.wami',
}) =>
    AppVersionStatus(
      currentVersion: '1.0.0',
      latestVersion: latest,
      updateAvailable: available,
      forceUpdate: force,
      forceUpdateAfter: after,
      downloadUrl: url,
      releaseNotes: 'Corrections et nouveautés',
    );

class _Repo implements AppUpdateRepository {
  _Repo(this.results);
  final List<Result<AppVersionStatus>> results;
  int calls = 0;

  @override
  Future<Result<AppVersionStatus>> check() async => results[calls++ < results.length ? calls - 1 : results.length - 1];
}

class _Opener implements UrlOpener {
  _Opener({this.ok = true});
  final bool ok;
  final opened = <String>[];

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return ok;
  }
}

class _FixedSource implements AppUpdateRemoteDataSource {
  _FixedSource(this.status);
  final AppVersionStatus status;

  @override
  Future<AppVersionStatus> check() async => status;
}

void main() {
  group('décision', () {
    final now = DateTime(2026, 11, 4, 12);

    test('à jour', () => expect(_status().requirementAt(now), UpdateRequirement.none));
    test(
      'version plus récente : rappel',
      () => expect(_status(available: true).requirementAt(now), UpdateRequirement.optional),
    );
    test('version trop ancienne : obligatoire', () {
      expect(_status(available: true, force: true).requirementAt(now), UpdateRequirement.required);
    });

    test('date limite : rappel avant, obligatoire après', () {
      final deadline = DateTime(2026, 11, 10);
      expect(_status(available: true, after: deadline).requirementAt(now), UpdateRequirement.optional);
      expect(
        _status(available: true, after: deadline).requirementAt(DateTime(2026, 11, 10)),
        UpdateRequirement.required,
      );
      expect(_status(available: true, after: deadline).requirementAt(DateTime(2026, 12)), UpdateRequirement.required);
    });

    test('une date limite ne rend rien obligatoire si on est à jour', () {
      expect(_status(after: DateTime(2026, 1)).requirementAt(now), UpdateRequirement.none);
    });
  });

  group('source de données', () {
    test('version et plateforme envoyées, réponse lue', () async {
      final server = StubServer()
        ..on('GET /api/app-config/check-version', {
          'success': true,
          'data': {
            'currentVersion': '0.1.0',
            'latestVersion': '1.0.0',
            'updateAvailable': true,
            'forceUpdate': true,
            'forceUpdateAfter': '2026-12-01T00:00:00.000Z',
            'downloadUrl': 'https://apps.apple.com/app/wami',
            'releaseNotes': 'Première version',
          },
        });
      final source = AppUpdateApiDataSource(
        server.client(),
        const FixedAppInfoSource(AppInfo(version: '0.1.0', platform: 'IOS')),
      );

      final s = await source.check();

      expect(server.last('GET /api/app-config/check-version')!.queryParameters, {
        'appType': 'PASSENGER',
        'platform': 'IOS',
        'currentVersion': '0.1.0',
      });
      expect(s.updateAvailable, isTrue);
      expect(s.forceUpdate, isTrue);
      expect(s.latestVersion, '1.0.0');
      expect(s.forceUpdateAfter, isNotNull);
      expect(s.downloadUrl, 'https://apps.apple.com/app/wami');
    });

    test('configuration introuvable : une erreur, pas un blocage', () {
      final server = StubServer()
        ..on(
          'GET /api/app-config/check-version',
          {
            'success': false,
            'error': {'message': 'AppVersionConfig not found', 'code': 'NOT_FOUND'},
          },
          status: 404,
        );
      final source = AppUpdateApiDataSource(server.client(), const FixedAppInfoSource());
      expect(source.check(), throwsA(isA<BusinessRuleException>()));
    });
  });

  group('état', () {
    late _Opener opener;
    var clock = DateTime(2026, 11, 4, 12);

    UpdateCubit cubit(_Repo repo, {bool enabled = true}) =>
        UpdateCubit(CheckAppVersion(repo), opener, enabled: enabled, clock: () => clock);

    setUp(() {
      opener = _Opener();
      clock = DateTime(2026, 11, 4, 12);
    });

    test('désactivé : aucune vérification', () async {
      final repo = _Repo([Ok(_status(force: true))]);
      final c = cubit(repo, enabled: false);
      await c.check();
      expect(repo.calls, 0);
      expect(c.state.blocking, isFalse);
      await c.close();
    });

    test('version trop ancienne : bloquant', () async {
      final c = cubit(_Repo([Ok(_status(available: true, force: true))]));
      await c.check();
      expect(c.state.blocking, isTrue);
      expect(c.state.reminder, isFalse);
      await c.close();
    });

    test('rappel facultatif, repoussé jusqu’au prochain lancement', () async {
      final c = cubit(_Repo([Ok(_status(available: true))]));
      await c.check();
      expect(c.state.reminder, isTrue);
      c.dismissReminder();
      expect(c.state.reminder, isFalse);
      expect(c.state.blocking, isFalse);
      await c.close();
    });

    test('une panne ne bloque jamais, et ne lève pas un blocage déjà connu', () async {
      final repo = _Repo([
        Ok(_status(available: true, force: true)),
        const Err(NetworkFailure()),
      ]);
      final c = cubit(repo);
      await c.check();
      expect(c.state.blocking, isTrue);
      await c.check(force: true);
      expect(c.state.blocking, isTrue, reason: 'la panne ne change rien');
      await c.close();
    });

    test('panne au premier essai : l’application reste utilisable', () async {
      final c = cubit(_Repo([const Err(NetworkFailure())]));
      await c.check();
      expect(c.state.blocking, isFalse);
      expect(c.state.reminder, isFalse);
      await c.close();
    });

    test('au retour dans l’application : au plus une vérification par demi-heure', () async {
      final repo = _Repo([Ok(_status())]);
      final c = cubit(repo);
      await c.check();
      clock = clock.add(const Duration(minutes: 10));
      await c.check();
      expect(repo.calls, 1);
      clock = clock.add(const Duration(minutes: 25));
      await c.check();
      expect(repo.calls, 2);
      await c.check(force: true);
      expect(repo.calls, 3);
      await c.close();
    });

    test('ouvrir le magasin', () async {
      final c = cubit(_Repo([Ok(_status(available: true))]));
      await c.check();
      await c.openStore();
      expect(opener.opened, ['https://play.google.com/store/apps/details?id=bj.wami.wami']);
      expect(c.state.openFailed, isFalse);
      await c.close();
    });

    test('magasin impossible à ouvrir : signalé', () async {
      opener = _Opener(ok: false);
      final c = cubit(_Repo([Ok(_status(force: true))]));
      await c.check();
      await c.openStore();
      expect(c.state.openFailed, isTrue);
      await c.close();
    });

    test('adresse vide : signalé sans rien ouvrir', () async {
      final c = cubit(_Repo([Ok(_status(force: true, url: ''))]));
      await c.check();
      await c.openStore();
      expect(opener.opened, isEmpty);
      expect(c.state.openFailed, isTrue);
      await c.close();
    });
  });

  group('configuration', () {
    test('vérifié par défaut seulement avec le vrai back', () {
      expect(const AppConfig(apiBaseUrl: '', useFakeBackend: false).shouldCheckVersion, isTrue);
      expect(const AppConfig(apiBaseUrl: '', useFakeBackend: true).shouldCheckVersion, isFalse);
    });

    test('réglable dans les deux sens', () {
      expect(const AppConfig(apiBaseUrl: '', useFakeBackend: false, checkVersion: false).shouldCheckVersion, isFalse);
      expect(const AppConfig(apiBaseUrl: '', useFakeBackend: true, checkVersion: true).shouldCheckVersion, isTrue);
    });
  });

  group('écrans', () {
    late _Opener opener;

    Future<void> start(WidgetTester tester, AppVersionStatus status) async {
      // Chaque test repart d'une injection neuve.
      if (sl.isRegistered<AuthCubit>()) await sl<AuthCubit>().close();
      if (sl.isRegistered<UpdateCubit>()) await sl<UpdateCubit>().close();
      await sl.reset();
      final store = InMemorySessionStore();
      await store.write(
        const AuthSession(
          token: 't',
          userId: 'u',
          passengerId: 'p',
          walletId: 'w',
          phone: '+2290197123456',
          firstName: 'Awa',
          lastName: 'Dossou',
        ),
      );
      opener = _Opener();
      await configureDependencies(
        const AppConfig(apiBaseUrl: '', useFakeBackend: true, fakeLatency: Duration.zero, checkVersion: true),
        sessionStore: store,
      );
      // Le back simulé dit toujours « à jour » : on le remplace par la réponse voulue avant la première vérification.
      await sl.unregister<AppUpdateRemoteDataSource>();
      sl
        ..registerSingleton<AppUpdateRemoteDataSource>(_FixedSource(status))
        ..unregister<UrlOpener>()
        ..registerSingleton<UrlOpener>(opener);
      await sl<AuthCubit>().restore();
      await tester.pumpWidget(const WamiApp());
      await tester.pumpAndSettle();
    }

    testWidgets('version trop ancienne : écran bloquant, bouton de mise à jour', (tester) async {
      await start(tester, _status(available: true, force: true));

      expect(find.text('Mise à jour nécessaire'), findsOneWidget);
      expect(find.textContaining('Version installée : 1.0.0'), findsOneWidget);
      expect(find.text('Corrections et nouveautés'), findsOneWidget);

      await tester.tap(find.text('Mettre à jour'));
      await tester.pumpAndSettle();
      expect(opener.opened, ['https://play.google.com/store/apps/details?id=bj.wami.wami']);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('version plus récente : rappel que l’on peut repousser', (tester) async {
      await start(tester, _status(available: true, latest: '1.3.0'));

      expect(find.text('Nouvelle version disponible'), findsOneWidget);
      expect(find.text('WAMI 1.3.0'), findsOneWidget);
      expect(find.text('Mise à jour nécessaire'), findsNothing);
      // L'application reste utilisable derrière le rappel.
      expect(find.text('NOS SERVICES'), findsOneWidget);

      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle version disponible'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('à jour : rien à signaler', (tester) async {
      await start(tester, _status());
      expect(find.text('Nouvelle version disponible'), findsNothing);
      expect(find.text('Mise à jour nécessaire'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}

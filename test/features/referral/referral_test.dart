import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wami/app.dart';
import 'package:wami/app/di/injection.dart';
import 'package:wami/app/router/app_router.dart';
import 'package:wami/core/auth/auth_session.dart';
import 'package:wami/core/auth/session_store.dart';
import 'package:wami/core/config/app_config.dart';
import 'package:wami/core/di/service_locator.dart';
import 'package:wami/core/error/exceptions.dart';
import 'package:wami/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:wami/features/referral/data/datasources/referral_data_sources.dart';
import 'package:wami/features/referral/domain/entities/referral.dart';

import '../../support/stub_server.dart';

Map<String, dynamic> _ok(Object? data) => {'success': true, 'data': data};

void main() {
  group('source de données', () {
    late StubServer server;
    late ReferralApiDataSource referral;

    setUp(() {
      server = StubServer();
      referral = ReferralApiDataSource(server.client());
    });

    test('code, filleuls et compteurs', () async {
      server
        ..on('GET /api/passengers/profile', _ok({'referralCode': 'OAS381'}))
        ..on(
          'GET /api/passenger/referrals/my',
          _ok({
            'referrals': [
              {
                'referralId': 'r1',
                'referredName': 'Filleul Test',
                'status': 'PENDING',
                'referrerReward': 500,
                'createdAt': '2026-11-04T00:42:17.138Z',
                'validatedAt': null,
              },
              {
                'referralId': 'r2',
                'referredName': '',
                'status': 'VALIDATED',
                'referrerReward': 500,
                'createdAt': '2026-10-01T10:00:00.000Z',
                'validatedAt': '2026-10-03T10:00:00.000Z',
              },
            ],
            'total': 2,
            'totalPending': 1,
            'totalValidated': 1,
          }),
        )
        ..on('GET /api/passenger/referrals/my-pending', _ok(null));

      final o = await referral.overview();

      expect(o.code, 'OAS381');
      expect(o.total, 2);
      expect(o.pendingCount, 1);
      expect(o.validatedCount, 1);
      expect(o.referrals.first.name, 'Filleul Test');
      expect(o.referrals.first.status, ReferralStatus.pending);
      expect(o.referrals.last.name, 'Un proche');
      expect(o.referrals.last.status, ReferralStatus.validated);
      expect(o.rewardPerReferral, 500);
      expect(o.incoming, isNull);
    });

    test('parrainage en cours comme filleul', () async {
      server
        ..on('GET /api/passengers/profile', _ok({'referralCode': 'ABC123'}))
        ..on(
          'GET /api/passenger/referrals/my',
          _ok({'referrals': [], 'total': 0, 'totalPending': 0, 'totalValidated': 0}),
        )
        ..on(
          'GET /api/passenger/referrals/my-pending',
          _ok({'referralCode': 'OAS381', 'status': 'PENDING', 'referrerReward': 500, 'referredReward': 300}),
        );
      final o = await referral.overview();
      expect(o.incoming!.code, 'OAS381');
      expect(o.incoming!.reward, 300);
      expect(o.rewardPerReferral, isNull);
    });

    test('code appliqué', () async {
      server.on(
        'POST /api/passenger/referrals/apply',
        {
          'success': true,
          'data': {'referralId': 'x', 'referrerReward': 500, 'referredReward': 300, 'status': 'PENDING'},
        },
        status: 201,
      );
      final r = await referral.apply('OAS381');
      expect(server.last('POST /api/passenger/referrals/apply')!.data, {'referralCode': 'OAS381'});
      expect(r.reward, 300);
    });

    for (final c in [
      (404, "Referral code 'ZZZ' does not exist not found", 'Code de parrainage inconnu.'),
      (409, 'User has already been referred', 'Vous avez déjà utilisé un code de parrainage.'),
    ]) {
      test('refus ${c.$1} traduit', () async {
        server.on(
          'POST /api/passenger/referrals/apply',
          {
            'success': false,
            'error': {'message': c.$2, 'code': 'X'},
          },
          status: c.$1,
        );
        await expectLater(
          referral.apply('ZZZ'),
          throwsA(isA<BusinessRuleException>().having((e) => e.message, 'message', c.$3)),
        );
      });
    }

    test('refus : son propre code (motif dans details.error)', () async {
      server.on(
        'POST /api/passenger/referrals/apply',
        {
          'success': false,
          'error': {
            'message': 'Validation failed',
            'code': 'VALIDATION_ERROR',
            'details': {'error': 'Cannot refer yourself'},
          },
        },
        status: 422,
      );
      await expectLater(
        referral.apply('MOI'),
        throwsA(isA<BusinessRuleException>().having((e) => e.message, 'message', contains('propre code'))),
      );
    });
  });

  testWidgets('écran Parrainer un proche : code, filleuls, utiliser un code', (tester) async {
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
    await configureDependencies(
      const AppConfig(apiBaseUrl: '', useFakeBackend: true, fakeLatency: Duration.zero),
      sessionStore: store,
    );
    await sl<AuthCubit>().restore();
    await tester.pumpWidget(const WamiApp());
    await tester.pumpAndSettle();

    unawaited(sl<AppRouter>().config.push<void>('/account/referral'));
    await tester.pumpAndSettle();

    expect(find.text('WAMIAWA1'), findsOneWidget);
    expect(find.text('Koffi Adjovi'), findsOneWidget);
    expect(find.text('Validé'), findsOneWidget);
    expect(find.textContaining('Vous gagnez'), findsOneWidget);

    // Code inconnu : message, la saisie reste.
    await tester.enterText(find.byType(TextFormField), 'FAUX');
    await tester.ensureVisible(find.text('Utiliser ce code'));
    await tester.tap(find.text('Utiliser ce code'));
    await tester.pumpAndSettle();
    expect(find.text('Code de parrainage inconnu.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    // Bon code : le parrainage en cours remplace la saisie.
    await tester.enterText(find.byType(TextFormField), 'ami123');
    await tester.tap(find.text('Utiliser ce code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Parrainage en cours avec le code AMI123'), findsOneWidget);
    expect(find.text('Utiliser ce code'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}

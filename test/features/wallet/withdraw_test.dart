import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wami/app.dart';
import 'package:wami/app/di/injection.dart';
import 'package:wami/app/router/app_router.dart';
import 'package:wami/core/auth/auth_session.dart';
import 'package:wami/core/auth/session_store.dart';
import 'package:wami/core/config/app_config.dart';
import 'package:wami/core/di/service_locator.dart';
import 'package:wami/core/utils/result.dart';
import 'package:wami/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:wami/features/wallet/domain/entities/wallet.dart';
import 'package:wami/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:wami/features/wallet/domain/usecases/wallet_usecases.dart';

class _MockRepo extends Mock implements WalletRepository {}

const _mobile = WithdrawRequest(amount: 5000, method: WithdrawMethod.mobileMoney, phone: '+2290197123456');

void main() {
  group('règles du retrait', () {
    late _MockRepo repo;
    late RequestWithdrawal withdraw;

    setUpAll(() => registerFallbackValue(_mobile));

    setUp(() {
      repo = _MockRepo();
      withdraw = RequestWithdrawal(repo);
      when(() => repo.withdraw(any())).thenAnswer((_) async => const Ok(Withdrawal(id: 'wd', amount: 5000)));
    });

    test('envoie la demande quand tout est en règle', () async {
      final r = await withdraw(const WithdrawParams(request: _mobile, withdrawable: 18000));
      expect(r.isOk, isTrue);
      verify(() => repo.withdraw(_mobile)).called(1);
    });

    test('refuse sans appel : montant sous le minimum, au-dessus des gains, coordonnées absentes', () async {
      const tooSmall = WithdrawRequest(amount: 500, method: WithdrawMethod.mobileMoney, phone: '+2290197123456');
      const bankSmall = WithdrawRequest(
        amount: 3000,
        method: WithdrawMethod.bank,
        bankName: 'Ecobank',
        accountName: 'Awa',
        iban: 'BJ1',
      );
      const noPhone = WithdrawRequest(amount: 5000, method: WithdrawMethod.mobileMoney);
      const noIban = WithdrawRequest(amount: 6000, method: WithdrawMethod.bank, bankName: 'Ecobank');
      for (final (request, withdrawable) in [
        (tooSmall, 18000),
        (bankSmall, 18000),
        (_mobile, 4000),
        (noPhone, 18000),
        (noIban, 18000),
      ]) {
        final r = await withdraw(WithdrawParams(request: request, withdrawable: withdrawable));
        expect(r.isOk, isFalse, reason: '$request');
      }
      verifyNever(() => repo.withdraw(any()));
    });
  });

  testWidgets('retrait à l’écran : gains visibles, demande envoyée, gains restants mis à jour', (tester) async {
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

    final router = sl<AppRouter>().config;
    router.go('/wallet');
    await tester.pumpAndSettle();
    // Les gains d'affilié sont montrés à part du solde dépensable.
    expect(find.text('Gains d’affilié'), findsOneWidget);

    unawaited(router.push<void>('/wallet/withdraw'));
    await tester.pumpAndSettle();
    expect(find.text('Retirer mes gains'), findsOneWidget);

    // Un montant trop grand est refusé avant tout appel.
    await tester.enterText(find.byType(TextFormField).first, '99999');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Retirer 99'));
    await tester.pumpAndSettle();
    expect(find.text('Vous ne pouvez pas retirer plus que vos gains d’affilié.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));

    await tester.enterText(find.byType(TextFormField).first, '5000');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Retirer 5'));
    await tester.pumpAndSettle();
    expect(find.text('Demande de retrait envoyée'), findsOneWidget);
    expect(find.textContaining('13'), findsWidgets, reason: '18 000 − 5 000 de gains restants');
  });
}

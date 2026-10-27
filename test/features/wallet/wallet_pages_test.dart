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
import 'package:wami/features/auth/presentation/cubit/auth_cubit.dart';

void main() {
  testWidgets('recharge et transfert : moyens enregistrés, contacts et saisie d’un autre numéro', (tester) async {
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

    // Recharge : les moyens enregistrés sont proposés, plus « Autre numéro ».
    unawaited(router.push<void>('/wallet/top-up'));
    await tester.pumpAndSettle();
    expect(find.text('Carte bancaire'), findsOneWidget);
    expect(find.text('Autre numéro Mobile Money'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('Autre numéro Mobile Money'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);

    // Transfert : les contacts sont là, « Nouveau » fait apparaître la saisie d’un numéro.
    unawaited(router.pushReplacement<void>('/wallet/transfer'));
    await tester.pumpAndSettle();
    expect(find.text('[Contact A]'), findsOneWidget);
    expect(find.text('Le destinataire doit avoir un compte WAMI.'), findsNothing);
    await tester.tap(find.text('Nouveau'));
    await tester.pumpAndSettle();
    expect(find.text('Le destinataire doit avoir un compte WAMI.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}

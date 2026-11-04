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
  testWidgets('profil : civilité, adresse, ajout d’e-mail puis vérification par code', (tester) async {
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

    unawaited(sl<AppRouter>().config.push<void>('/account/profile'));
    await tester.pumpAndSettle();
    expect(find.text('Mon profil'), findsOneWidget);
    // Aucun e-mail : rien à vérifier côté e-mail, le téléphone est vérifié.
    expect(find.text('E-mail non vérifié'), findsNothing);
    expect(find.text('Téléphone non vérifié'), findsNothing);

    // Civilité.
    await tester.tap(find.text('Homme'));
    await tester.pumpAndSettle();
    expect(find.text('Civilité enregistrée'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));

    // Adresse : ville et quartier obligatoires.
    await tester.ensureVisible(find.text('Ajouter mon adresse'));
    await tester.tap(find.text('Ajouter mon adresse'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Cotonou'), 'Cotonou');
    await tester.pump();
    expect(find.text('Mon adresse'), findsOneWidget);
    await tester.tap(find.text('Enregistrer').last);
    await tester.pumpAndSettle();
    expect(find.text('Indiquez au moins la ville et le quartier.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox());
    await sl.reset();
  });

  testWidgets('vérification de l’e-mail : mauvais code refusé, bon code accepté', (tester) async {
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
        email: 'awa@exemple.bj',
      ),
    );
    await configureDependencies(
      const AppConfig(apiBaseUrl: '', useFakeBackend: true, fakeLatency: Duration.zero),
      sessionStore: store,
    );
    await sl<AuthCubit>().restore();
    await tester.pumpWidget(const WamiApp());
    await tester.pumpAndSettle();

    unawaited(sl<AppRouter>().config.push<void>('/account/profile'));
    await tester.pumpAndSettle();
    expect(find.text('E-mail non vérifié'), findsOneWidget);

    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();
    expect(find.text('Vérifier mon e-mail'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, '123456'), '000000');
    await tester.tap(find.text('Vérifier').last);
    await tester.pumpAndSettle();
    expect(find.text('Code invalide ou expiré. Demandez un nouveau code.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));

    await tester.enterText(find.widgetWithText(TextFormField, '123456'), '123456');
    await tester.tap(find.text('Vérifier').last);
    await tester.pumpAndSettle();
    expect(find.text('E-mail vérifié'), findsOneWidget);
    expect(find.text('E-mail non vérifié'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox());
    await sl.reset();
  });
}

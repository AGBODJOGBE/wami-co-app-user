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
  testWidgets('mot de passe, déconnexion et suppression du compte', (tester) async {
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

    // Changer le mot de passe : les règles s'appliquent, puis retour au compte.
    unawaited(router.push<void>('/account/password'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Ancien1pass');
    await tester.enterText(fields.at(1), 'faible');
    await tester.enterText(fields.at(2), 'faible');
    await tester.tap(find.text('Modifier le mot de passe'));
    await tester.pumpAndSettle();
    expect(
      find.text('Mot de passe'),
      findsWidgets,
      reason: 'on reste sur la page tant que les règles ne sont pas respectées',
    );

    // Le message d'erreur s'affiche en bas et cache le bouton : on attend qu'il disparaisse.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await tester.enterText(fields.at(1), 'Nouveau2pass');
    await tester.enterText(fields.at(2), 'Nouveau2pass');
    await tester.tap(find.text('Modifier le mot de passe'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier le mot de passe'), findsNothing);

    // Suppression : mot de passe demandé, puis retour à la connexion.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    unawaited(router.push<void>('/account/privacy'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Supprimer mon compte'));
    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer mon compte ?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Motdepasse1');
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(sl<AuthCubit>().state.isAuthenticated, isFalse);
    expect(find.text('Bienvenue'), findsOneWidget);
    expect(await store.read(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('se déconnecter depuis le compte', (tester) async {
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
    await sl<AuthCubit>().close();
    await sl.reset();
    await configureDependencies(
      const AppConfig(apiBaseUrl: '', useFakeBackend: true, fakeLatency: Duration.zero),
      sessionStore: store,
    );
    await sl<AuthCubit>().restore();
    await tester.pumpWidget(const WamiApp());
    await tester.pumpAndSettle();

    sl<AppRouter>().config.go('/account');
    await tester.pumpAndSettle();
    // La barre de navigation flottante recouvre le bas de la liste : on fait remonter le bouton.
    await tester.dragUntilVisible(find.text('Se déconnecter'), find.byType(Scrollable).first, const Offset(0, -80));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();
    expect(find.text('Se déconnecter ?'), findsOneWidget);

    // Annuler ne déconnecte pas.
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(sl<AuthCubit>().state.isAuthenticated, isTrue);

    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Se déconnecter'));
    await tester.pumpAndSettle();
    expect(sl<AuthCubit>().state.isAuthenticated, isFalse);
    expect(find.text('Bienvenue'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}

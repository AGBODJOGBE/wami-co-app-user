import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wami/app.dart';
import 'package:wami/app/di/injection.dart';
import 'package:wami/core/auth/session_store.dart';
import 'package:wami/core/config/app_config.dart';
import 'package:wami/core/di/service_locator.dart';
import 'package:wami/features/auth/presentation/cubit/auth_cubit.dart';

/// Parcours complet sur le faux backend : numéro → code → inscription → accueil → déconnexion → reconnexion.
void main() {
  testWidgets('inscription puis reconnexion', (tester) async {
    final store = InMemorySessionStore();
    await configureDependencies(
      const AppConfig(apiBaseUrl: '', useFakeBackend: true, fakeLatency: Duration.zero),
      sessionStore: store,
    );
    await sl<AuthCubit>().restore();

    await tester.pumpWidget(const WamiApp());
    await tester.pumpAndSettle();

    // Non connecté : on arrive sur la saisie du numéro.
    expect(find.text('Bienvenue'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '01 97 12 34 56');
    await tester.tap(find.text('Recevoir le code'));
    await tester.pumpAndSettle();
    expect(find.text('Code de vérification'), findsOneWidget);

    // Un mauvais code est refusé et on reste sur l'étape.
    await tester.enterText(find.byType(TextFormField), '000000');
    await tester.pumpAndSettle();
    expect(find.text('Code de vérification'), findsOneWidget);
    // Le message d'erreur masquerait le bas du formulaire suivant.
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).removeCurrentSnackBar();

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.pumpAndSettle();

    // Numéro inconnu : formulaire d'inscription.
    expect(find.text('Créer votre compte'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Awa');
    await tester.enterText(fields.at(1), 'Dossou');
    await tester.ensureVisible(find.text('Femme'));
    await tester.tap(find.text('Femme'));
    // Champs : prénom, nom, mot de passe, puis e-mail et parrainage (facultatifs).
    await tester.enterText(fields.at(2), 'Motdepasse1');
    await tester.ensureVisible(find.text('Créer mon compte'));
    await tester.tap(find.text('Créer mon compte'));
    await tester.pumpAndSettle();

    expect(sl<AuthCubit>().state.isAuthenticated, isTrue);
    expect((await store.read())?.fullName, 'Awa Dossou');
    expect(find.text('NOS SERVICES'), findsOneWidget);

    await sl<AuthCubit>().logout();
    await tester.pumpAndSettle();
    expect(find.text('Bienvenue'), findsOneWidget);
    expect(await store.read(), isNull);

    // Le numéro est maintenant connu : le code mène au mot de passe.
    await tester.enterText(find.byType(TextFormField), '0197123456');
    await tester.tap(find.text('Recevoir le code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.pumpAndSettle();
    expect(find.text('Bon retour'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'mauvais');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(sl<AuthCubit>().state.isAuthenticated, isFalse);

    await tester.enterText(find.byType(TextFormField), 'Motdepasse1');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(sl<AuthCubit>().state.isAuthenticated, isTrue);

    await tester.pumpWidget(const SizedBox());
  });
}

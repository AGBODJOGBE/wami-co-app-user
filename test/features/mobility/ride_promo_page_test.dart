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
  testWidgets('code promo sur l’écran des prix : codes proposés, remise, refus et retrait', (tester) async {
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

    // Destination → écran des prix.
    sl<AppRouter>().config.go('/ride');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Dantokpa');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Dantokpa').last);
    await tester.pumpAndSettle();
    expect(find.text('Choisissez votre véhicule'), findsOneWidget);
    expect(find.textContaining('800'), findsWidgets);

    // Ouvre la saisie : le code proposé par le back est là.
    await tester.tap(find.text('Code promo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('WAMI10'), findsOneWidget);

    // Un code refusé : message, pas de remise.
    await tester.enterText(find.byType(TextFormField).last, 'FAUX');
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();
    expect(find.text('Code promo inconnu.'), findsOneWidget);
    expect(find.text('Code promo'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    // Un code accepté : la moto passe de 800 à 720, l'ancien prix reste barré.
    await tester.tap(find.text('Code promo'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('WAMI10'));
    await tester.pumpAndSettle();
    expect(find.textContaining('720'), findsWidgets);
    expect(find.text('WAMI10'), findsOneWidget);

    // Retrait du code.
    await tester.tap(find.text('WAMI10'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('720'), findsNothing);
    expect(find.text('Code promo'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wami/app.dart';
import 'package:wami/app/di/injection.dart';
import 'package:wami/core/auth/auth_session.dart';
import 'package:wami/core/auth/session_store.dart';
import 'package:wami/core/config/app_config.dart';
import 'package:wami/core/di/service_locator.dart';
import 'package:wami/features/auth/presentation/cubit/auth_cubit.dart';

void main() {
  testWidgets('connecté, l’accueil affiche les services avec le faux backend', (tester) async {
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('NOS SERVICES'), findsOneWidget);
    expect(find.text('Mobilité'), findsWidgets);

    // Démonte l'app pour arrêter le défilement automatique du carrousel.
    await tester.pumpWidget(const SizedBox());
  });
}

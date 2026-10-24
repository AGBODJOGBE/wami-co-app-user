import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wami/app.dart';
import 'package:wami/app/di/injection.dart';
import 'package:wami/core/config/app_config.dart';

void main() {
  testWidgets('l’accueil affiche les services avec le faux backend', (tester) async {
    await configureDependencies(
      const AppConfig(apiBaseUrl: '', useFakeBackend: true, fakeLatency: Duration.zero),
    );
    await tester.pumpWidget(const WamiApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('NOS SERVICES'), findsOneWidget);
    expect(find.text('Mobilité'), findsWidgets);

    // Démonte l'app pour arrêter le défilement automatique du carrousel.
    await tester.pumpWidget(const SizedBox());
  });
}

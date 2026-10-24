import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'app/di/injection.dart';
import 'core/di/service_locator.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Lancement : flutter run --dart-define=WAMI_FAKE_BACKEND=false --dart-define=WAMI_API_URL=https://api.exemple.bj
  final config = AppConfig.fromEnvironment();
  await configureDependencies(config);
  // Reprend la session de l'appareil avant d'afficher quoi que ce soit : pas d'écran de connexion qui clignote.
  await sl<AuthCubit>().restore();

  runApp(const WamiApp());
}

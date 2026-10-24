import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'app/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Lancement : flutter run --dart-define=WAMI_FAKE_BACKEND=false --dart-define=WAMI_API_URL=https://api.exemple.bj
  final config = AppConfig.fromEnvironment();
  await configureDependencies(config);

  runApp(const WamiApp());
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/service_locator.dart';
import 'app/router/app_router.dart';
import 'core/theme/wami_theme.dart';
import 'features/account/domain/entities/app_settings.dart';
import 'features/account/presentation/cubit/profile_cubit.dart';
import 'features/account/presentation/cubit/settings_cubit.dart';
import 'features/wallet/presentation/bloc/wallet_bloc.dart';

/// Racine de l'application.
///
/// Les blocs fournis ici sont *globaux* : leur état sert à plusieurs écrans
/// (solde du portefeuille, thème, profil). Les blocs d'un parcours
/// (course, livraison, bus, hébergement) sont fournis par leur ShellRoute
/// et détruits à la sortie du parcours.
class WamiApp extends StatelessWidget {
  const WamiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<SettingsCubit>()..load()),
        BlocProvider(create: (_) => sl<ProfileCubit>()..load()),
        BlocProvider(create: (_) => sl<WalletBloc>()..add(const WalletStarted())),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        buildWhen: (a, b) => a.settings.themeMode != b.settings.themeMode,
        builder: (context, state) {
          return MaterialApp.router(
            title: 'WAMI',
            debugShowCheckedModeBanner: false,
            theme: WamiTheme.light(),
            darkTheme: WamiTheme.dark(),
            themeMode: _toThemeMode(state.settings.themeMode),
            routerConfig: sl<AppRouter>().config,
          );
        },
      ),
    );
  }

  ThemeMode _toThemeMode(AppThemeMode mode) => switch (mode) {
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.system => ThemeMode.system,
      };
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/router/app_router.dart';
import 'core/di/service_locator.dart';
import 'core/theme/wami_theme.dart';
import 'features/account/domain/entities/app_settings.dart';
import 'features/account/presentation/cubit/profile_cubit.dart';
import 'features/account/presentation/cubit/settings_cubit.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/wallet/presentation/bloc/wallet_bloc.dart';

/// Racine de l'application.
///
/// Les blocs fournis ici sont *globaux* : leur état sert à plusieurs écrans
/// (session, solde du portefeuille, thème, profil). Les blocs d'un parcours
/// (course, livraison, bus, hébergement) sont fournis par leur ShellRoute
/// et détruits à la sortie du parcours.
class WamiApp extends StatelessWidget {
  const WamiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<AuthCubit>()),
        BlocProvider(create: (_) => sl<SettingsCubit>()..load()),
        // Profil et portefeuille ne se chargent qu'une fois connecté : voir _SessionBridge.
        BlocProvider(create: (_) => sl<ProfileCubit>()),
        BlocProvider(create: (_) => sl<WalletBloc>()),
      ],
      child: _SessionBridge(
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
      ),
    );
  }

  ThemeMode _toThemeMode(AppThemeMode mode) => switch (mode) {
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.system => ThemeMode.system,
      };
}

/// Charge les données de l'utilisateur à la connexion et les efface à la déconnexion.
class _SessionBridge extends StatefulWidget {
  const _SessionBridge({required this.child});
  final Widget child;

  @override
  State<_SessionBridge> createState() => _SessionBridgeState();
}

class _SessionBridgeState extends State<_SessionBridge> {
  @override
  void initState() {
    super.initState();
    // Session reprise au démarrage : le listener ci-dessous ne s'y déclenche pas.
    if (context.read<AuthCubit>().state.isAuthenticated) _load(context);
  }

  void _load(BuildContext context) {
    context.read<ProfileCubit>().load();
    context.read<WalletBloc>().add(const WalletStarted());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (a, b) => a.isAuthenticated != b.isAuthenticated,
      listener: (context, state) {
        if (state.isAuthenticated) {
          _load(context);
        } else {
          context.read<ProfileCubit>().reset();
          context.read<WalletBloc>().add(const WalletCleared());
        }
      },
      child: widget.child,
    );
  }
}

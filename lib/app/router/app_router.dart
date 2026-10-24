import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';

import 'package:go_router/go_router.dart';

import '../../features/account/presentation/pages/account_detail_pages.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/sign_in_cubit.dart';
import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/account/presentation/pages/account_page.dart';
import '../../features/activities/presentation/activities_page.dart';
import '../../features/bus/presentation/cubit/bus_booking_cubit.dart';
import '../../features/bus/presentation/pages/bus_compare_page.dart';
import '../../features/bus/presentation/pages/bus_results_page.dart';
import '../../features/bus/presentation/pages/bus_search_page.dart';
import '../../features/bus/presentation/pages/bus_seat_page.dart';
import '../../features/bus/presentation/pages/bus_ticket_page.dart';
import '../../features/delivery/presentation/cubit/delivery_cubit.dart';
import '../../features/delivery/presentation/pages/delivery_address_page.dart';
import '../../features/delivery/presentation/pages/delivery_parcel_page.dart';
import '../../features/delivery/presentation/pages/delivery_quote_page.dart';
import '../../features/delivery/presentation/pages/delivery_tracking_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/lodging/presentation/cubit/lodging_cubit.dart';
import '../../features/lodging/presentation/pages/lodging_booking_pages.dart';
import '../../features/lodging/presentation/pages/lodging_search_pages.dart';
import '../../features/mobility/presentation/bloc/ride_bloc.dart';
import '../../features/mobility/presentation/pages/ride_destination_page.dart';
import '../../features/mobility/presentation/pages/ride_offers_page.dart';
import '../../features/mobility/presentation/pages/ride_rating_page.dart';
import '../../features/mobility/presentation/pages/ride_tracking_page.dart';
import '../../features/wallet/presentation/pages/wallet_operation_pages.dart';
import '../../features/wallet/presentation/pages/wallet_page.dart';
import '../../core/di/service_locator.dart';
import '../../core/router/routes.dart';
import 'app_shell.dart';

/// Navigation de l'application (go_router).
///
/// - Les 4 onglets sont des branches d'un `StatefulShellRoute` (chaque onglet garde sa pile).
/// - Chaque parcours (course, livraison, bus, hébergement) est un `ShellRoute` qui
///   **fournit le bloc du parcours** à toutes ses étapes, puis le détruit à la sortie.
class AppRouter {
  AppRouter(this._auth);
  final AuthCubit _auth;

  final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  late final GoRouter config = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.home,
    refreshListenable: _AuthRefresh(_auth.stream),
    redirect: (context, state) {
      final signedIn = _auth.state.isAuthenticated;
      final onAuth = state.matchedLocation == Routes.auth;
      if (!signedIn && !onAuth) return Routes.auth;
      if (signedIn && onAuth) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.auth,
        builder: (_, __) => BlocProvider(create: (_) => sl<SignInCubit>(), child: const SignInPage()),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.home, builder: (_, __) => const HomePage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.activities, builder: (_, __) => const ActivitiesPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.wallet,
                builder: (_, __) => const WalletPage(),
                routes: [
                  _full('top-up', (_) => const TopUpPage()),
                  _full(
                    'transfer',
                    (_) => const TransferPage(),
                    routes: [
                      GoRoute(
                        path: 'review',
                        parentNavigatorKey: _rootKey,
                        builder: (_, s) => TransferReviewPage(draft: s.extra! as TransferDraft),
                      ),
                    ],
                  ),
                  _full('success', (_) => const WalletSuccessPage()),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.account,
                builder: (_, __) => const AccountPage(),
                routes: [
                  _full('profile', (_) => const ProfilePage()),
                  _full('settings', (_) => const SettingsPage()),
                  _full('support', (_) => const SupportPage()),
                  _full('privacy', (_) => const PrivacyPage()),
                ],
              ),
            ],
          ),
        ],
      ),

      // ── Parcours Mobilité ──
      ShellRoute(
        parentNavigatorKey: _rootKey,
        builder: (_, __, child) => BlocProvider(create: (_) => sl<RideBloc>(), child: child),
        routes: [
          GoRoute(
            path: Routes.ride,
            builder: (_, s) => RideDestinationPage(initialQuery: s.extra as String?),
            routes: [
              GoRoute(path: 'offers', builder: (_, __) => const RideOffersPage()),
              GoRoute(path: 'track', builder: (_, __) => const RideTrackingPage()),
              GoRoute(path: 'rate', builder: (_, __) => const RideRatingPage()),
            ],
          ),
        ],
      ),

      // ── Parcours Livraison ──
      ShellRoute(
        parentNavigatorKey: _rootKey,
        builder: (_, __, child) => BlocProvider(create: (_) => sl<DeliveryCubit>(), child: child),
        routes: [
          GoRoute(
            path: Routes.delivery,
            builder: (_, __) => const DeliveryAddressPage(),
            routes: [
              GoRoute(path: 'parcel', builder: (_, __) => const DeliveryParcelPage()),
              GoRoute(path: 'quote', builder: (_, __) => const DeliveryQuotePage()),
              GoRoute(path: 'track', builder: (_, __) => const DeliveryTrackingPage()),
            ],
          ),
        ],
      ),

      // ── Parcours Bus ──
      ShellRoute(
        parentNavigatorKey: _rootKey,
        builder: (_, __, child) => BlocProvider(create: (_) => sl<BusBookingCubit>(), child: child),
        routes: [
          GoRoute(
            path: Routes.bus,
            builder: (_, __) => const BusSearchPage(),
            routes: [
              GoRoute(path: 'results', builder: (_, __) => const BusResultsPage()),
              GoRoute(path: 'compare', builder: (_, __) => const BusComparePage()),
              GoRoute(path: 'seats', builder: (_, __) => const BusSeatPage()),
              GoRoute(path: 'ticket', builder: (_, __) => const BusTicketPage()),
            ],
          ),
        ],
      ),

      // ── Parcours Hébergement ──
      ShellRoute(
        parentNavigatorKey: _rootKey,
        builder: (_, __, child) => BlocProvider(create: (_) => sl<LodgingCubit>(), child: child),
        routes: [
          GoRoute(
            path: Routes.stay,
            builder: (_, __) => const LodgingSearchPage(),
            routes: [
              GoRoute(path: 'results', builder: (_, __) => const LodgingResultsPage()),
              GoRoute(path: 'detail', builder: (_, __) => const LodgingDetailPage()),
              GoRoute(path: 'confirm', builder: (_, __) => const LodgingConfirmPage()),
              GoRoute(path: 'booked', builder: (_, __) => const LodgingBookedPage()),
              GoRoute(path: 'apartment', builder: (_, __) => const ApartmentPage()),
              GoRoute(path: 'visit-sent', builder: (_, __) => const VisitSentPage()),
            ],
          ),
        ],
      ),
    ],
  );

  /// Sous-page d'onglet affichée en plein écran (sans la barre de navigation).
  GoRoute _full(String path, Widget Function(GoRouterState s) build, {List<RouteBase> routes = const []}) {
    return GoRoute(
      path: path,
      parentNavigatorKey: _rootKey,
      builder: (_, s) => build(s),
      routes: routes,
    );
  }
}

/// Fait réévaluer les redirections du routeur à chaque changement de session.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<AuthState> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

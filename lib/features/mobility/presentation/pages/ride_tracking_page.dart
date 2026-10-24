import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/wami_colors.dart';
import '../../../../core/theme/wami_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/route_map_view.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_live.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../domain/entities/ride.dart';
import '../bloc/ride_bloc.dart';
import '../widgets/ride_widgets.dart';

/// Étape 3 : suivi en temps réel. Le panneau change selon le statut de la course.
///
/// Règle validée : appel et message ne sont visibles qu'avant le démarrage
/// (chauffeur en route ou arrivé). Pendant la course : partage et urgence seulement.
class RideTrackingPage extends StatelessWidget {
  const RideTrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: BlocConsumer<RideBloc, RideState>(
          listenWhen: (a, b) => a.ride?.status != b.ride?.status,
          listener: (context, state) {
            final status = state.ride?.status;
            if (status == RideStatus.completed) context.pushReplacement(Routes.rideRate);
            if (status == RideStatus.cancelled || status == RideStatus.noDriver) {
              showWamiMessage(
                context,
                status == RideStatus.noDriver
                    ? 'Aucun chauffeur disponible pour le moment. Réessayez dans quelques minutes.'
                    : 'Course annulée.',
              );
              context.go(Routes.home);
            }
          },
          builder: (context, state) {
            final ride = state.ride;
            if (ride == null) return const WamiLoading();
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 480,
                  child: RouteMapView(progress: ride.status.isOnTrip ? ride.tripProgress : null),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: StatusPill(live: true, child: Text(_headline(ride))),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedSwitcher(
                    duration: WamiMotion.slow,
                    child: WamiSheet(
                      key: ValueKey(ride.status),
                      children: _panel(context, state, ride),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _headline(RideSnapshot r) => switch (r.status) {
        RideStatus.searching => 'Recherche d’un chauffeur…',
        RideStatus.driverEnRoute => r.etaMinutes > 0 ? 'Chauffeur à ${r.etaMinutes} min' : 'Chauffeur en route',
        RideStatus.driverArrived => 'Votre chauffeur est là',
        RideStatus.inProgress => r.etaMinutes > 0 ? 'En route · arrivée dans ${r.etaMinutes} min' : 'En route',
        RideStatus.paused => 'Course en pause',
        RideStatus.completed => 'Vous êtes arrivé',
        RideStatus.cancelled => 'Course annulée',
        RideStatus.noDriver => 'Aucun chauffeur disponible',
      };

  List<Widget> _panel(BuildContext context, RideState state, RideSnapshot ride) {
    final bloc = context.read<RideBloc>();
    void soon(String what) => showWamiMessage(context, '$what : bientôt disponible');
    final driver = ride.driver;

    switch (ride.status) {
      case RideStatus.searching:
        return [
          const Center(child: SearchingRadar()),
          Text(
            'Nous contactons les chauffeurs ${ride.category.label} proches de vous.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          WamiGhostButton(label: 'Annuler la demande', onPressed: () => bloc.add(const RideCancelled())),
        ];

      case RideStatus.driverEnRoute:
      case RideStatus.driverArrived:
        return [
          if (driver != null) DriverCard(driver: driver),
          if (ride.status == RideStatus.driverArrived)
            WaitingMeter(waitedSeconds: ride.waitedSeconds, fee: ride.waitingFee, policy: state.policy),
          if (ride.status.canContactDriver && driver != null)
            ContactDock(
              driverName: driver.name,
              onMessage: () => soon('Messagerie'),
              onCall: () => soon('Appel'),
              onShare: () => soon('Partage du trajet'),
            ),
          TextButton(
            onPressed: () => bloc.add(const RideCancelled()),
            child: const Text('Annuler la course'),
          ),
        ];

      case RideStatus.inProgress:
      case RideStatus.paused:
        return [
          if (ride.status == RideStatus.paused)
            PauseBanner(pausedSeconds: ride.pausedSeconds, fee: ride.pauseFee, policy: state.policy),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.destination?.name ?? 'Destination',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    NumberText('${ride.etaMinutes} min', size: 14),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ride.tripProgress,
                    minHeight: 6,
                    color: WamiColors.orangeLight,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('Total en cours', style: Theme.of(context).textTheme.bodySmall),
                    const Spacer(),
                    NumberText(Fmt.fcfa(ride.total), size: 15),
                  ],
                ),
                Text(_extras(ride), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          // Plus d'appel ni de message : seulement partage et urgence.
          Row(
            children: [
              Expanded(
                child: WamiGhostButton(
                  label: 'Partager le trajet',
                  icon: Icons.ios_share_rounded,
                  onPressed: () => soon('Partage'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: WamiGhostButton(label: 'Urgence', icon: Icons.sos_rounded, onPressed: () => soon('Urgence')),
              ),
            ],
          ),
        ];

      case RideStatus.completed:
      case RideStatus.cancelled:
      case RideStatus.noDriver:
        return const [SizedBox(height: 120, child: WamiLoading())];
    }
  }

  String _extras(RideSnapshot r) {
    final parts = <String>['course ${Fmt.fcfa(r.fare)}'];
    if (r.waitingFee > 0) parts.add('attente ${Fmt.fcfa(r.waitingFee)}');
    if (r.pauseFee > 0) parts.add('pause ${Fmt.fcfa(r.pauseFee)}');
    return parts.join(' · ');
  }
}

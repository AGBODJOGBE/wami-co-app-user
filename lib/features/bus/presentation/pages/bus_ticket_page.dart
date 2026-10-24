import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/service_type.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/wami_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../cubit/bus_booking_cubit.dart';
import '../widgets/bus_widgets.dart';

/// Billet confirmé + ventes croisées (course vers la gare, hôtel à l'arrivée).
class BusTicketPage extends StatelessWidget {
  const BusTicketPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ticket = context.watch<BusBookingCubit>().state.ticket;
    final t = Theme.of(context).textTheme;
    if (ticket == null) return const Scaffold(body: WamiLoading());
    final trip = ticket.trip;
    return WamiScreen(
      title: 'Bon voyage !',
      showBack: false,
      glow: ServiceType.bus.glow,
      actions: [WamiIconButton(icon: Icons.close_rounded, tooltip: 'Fermer', onPressed: () => context.go(Routes.home))],
      body: Gap(
        children: [
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Gap(
                    gap: 12,
                    children: [
                      Row(
                        children: [
                          Text(trip.company, style: t.titleSmall),
                          const Spacer(),
                          const WamiTag('Confirmé', tint: WamiColors.glowBus),
                        ],
                      ),
                      TripTimeline(trip: trip, fromLabel: ticket.query.from, toLabel: ticket.query.to),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _Info('Date', Fmt.dayMonth(ticket.query.date)),
                          _Info('Sièges', ticket.seats.join(', ')),
                          _Info('Gare', trip.station),
                        ],
                      ),
                    ],
                  ),
                ),
                const _Perforation(),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      TicketQr(payload: ticket.qrPayload),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionLabel('Embarquement'),
                            const SizedBox(height: 4),
                            Text(
                              'Présentez ce code au contrôleur, 30 min avant le départ.',
                              style: t.bodyMedium?.copyWith(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text('Réf. ${ticket.reference}', style: t.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(child: WamiGhostButton(label: 'Enregistrer', icon: Icons.download_rounded, onPressed: () {})),
              const SizedBox(width: 8),
              Expanded(child: WamiGhostButton(label: 'Partager', icon: Icons.ios_share_rounded, onPressed: () {})),
            ],
          ),
          const SectionLabel('Pour la suite du voyage'),
          Row(
            children: [
              Expanded(
                child: _CrossSell(
                  art: ServiceArt.auto,
                  title: 'Aller à la gare',
                  subtitle: 'Réserver une course',
                  onTap: () => context.go(Routes.ride),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CrossSell(
                  art: ServiceArt.hotel,
                  title: 'Dormir à ${ticket.query.to}',
                  subtitle: 'Voir les hôtels',
                  onTap: () => context.go(Routes.stay),
                ),
              ),
            ],
          ),
        ],
      ),
      bottom: WamiPrimaryButton(label: 'Retour à l’accueil', onPressed: () => context.go(Routes.home)),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.bodySmall),
        Text(value, style: t.titleSmall?.copyWith(fontSize: 13.5)),
      ],
    );
  }
}

class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final dashes = (c.maxWidth / 10).floor();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              for (var i = 0; i < dashes - 4; i++)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: i.isEven ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CrossSell extends StatelessWidget {
  const _CrossSell({required this.art, required this.title, required this.subtitle, required this.onTap});
  final ServiceArt art;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ServiceIllustration(art, size: 42),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.titleSmall?.copyWith(fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(subtitle, style: t.bodySmall?.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

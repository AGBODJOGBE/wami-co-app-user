import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/service_type.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/wami_colors.dart';
import '../../../../core/theme/wami_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../domain/entities/bus.dart';
import '../../domain/services/trip_ranking.dart';
import '../cubit/bus_booking_cubit.dart';

/// Comparatif côte à côte : le meilleur de chaque ligne est mis en orange.
class BusComparePage extends StatelessWidget {
  const BusComparePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BusBookingCubit>().state;
    final trips = state.compared;
    if (trips.length < 2) {
      return const WamiScreen(title: 'Comparatif', body: Text('Sélectionnez au moins deux départs.'));
    }
    final cmp = TripComparison(trips);
    final rows = <(String, String Function(BusTrip), bool Function(BusTrip))>[
      ('Prix', (t) => Fmt.fcfa(t.price), (t) => t.id == cmp.cheapest.id),
      ('Durée', (t) => Fmt.duration(t.durationMinutes), (t) => t.id == cmp.fastest.id),
      ('Départ', (t) => t.departure, (_) => false),
      ('Arrivée', (t) => t.arrival, (_) => false),
      ('Note', (t) => '★ ${t.rating}', (t) => t.id == cmp.bestRated.id),
      ('Confort', (t) => t.comfort.label, (t) => t.comfort == BusComfort.vip),
      ('Places', (t) => '${t.seatsLeft}', (t) => t.id == cmp.mostSeats.id),
    ];

    return WamiScreen(
      title: 'Comparatif',
      glow: ServiceType.bus.glow,
      body: Gap(
        children: [
          Text('En orange, le meilleur de chaque ligne.', style: Theme.of(context).textTheme.bodySmall),
          Table(
            columnWidths: const {0: FixedColumnWidth(66)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  const SizedBox.shrink(),
                  for (final t in trips)
                    _Cell(text: t.company.replaceAll('Compagnie ', 'Cie '), sub: t.departure, header: true),
                ],
              ),
              for (final (label, value, isBest) in rows)
                TableRow(
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
                    for (final t in trips) _Cell(text: value(t), best: isBest(t)),
                  ],
                ),
              TableRow(
                children: [
                  const SizedBox.shrink(),
                  for (final t in trips)
                    Padding(
                      padding: const EdgeInsets.all(3),
                      child: WamiPrimaryButton(
                        label: 'Choisir',
                        height: 40,
                        onPressed: () {
                          context.read<BusBookingCubit>().selectTrip(t);
                          context.push(Routes.busSeats);
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
          GlassCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WamiTag('Conseil WAMI', tint: WamiColors.glowBus),
                const SizedBox(width: 10),
                Expanded(child: Text(cmp.advice(Fmt.fcfa), style: Theme.of(context).textTheme.bodySmall)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.text, this.sub, this.best = false, this.header = false});
  final String text;
  final String? sub;
  final bool best;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final p = context.wami;
    return Container(
      margin: const EdgeInsets.all(3),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: header
            ? WamiColors.glowBus.withValues(alpha: 0.10)
            : (best ? WamiColors.orange.withValues(alpha: 0.18) : p.glass),
        border: best ? Border.all(color: WamiColors.orangeLight.withValues(alpha: 0.55)) : null,
      ),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: best || header ? FontWeight.w700 : FontWeight.w500,
              color: best ? (context.isDark ? WamiColors.orangePeach : WamiColors.orangeDeep) : p.ink,
            ),
          ),
          if (sub != null) Text(sub!, style: TextStyle(fontSize: 10.5, color: p.inkMuted)),
        ],
      ),
    );
  }
}

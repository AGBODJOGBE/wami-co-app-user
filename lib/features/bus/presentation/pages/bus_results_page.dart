import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/service_type.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/wami_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/load_status.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../../../core/widgets/wami_selectors.dart';
import '../../domain/entities/bus.dart';
import '../cubit/bus_booking_cubit.dart';
import '../widgets/bus_widgets.dart';

class BusResultsPage extends StatelessWidget {
  const BusResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BusBookingCubit>();
    return BlocConsumer<BusBookingCubit, BusBookingState>(
      listenWhen: (a, b) => b.failure != null && a.failure != b.failure,
      listener: (context, state) => showWamiMessage(context, state.failure!.message),
      builder: (context, state) {
        final q = state.query;
        final best = state.bestTrip;
        return WamiScreen(
          title: '${q.from} → ${q.to}',
          subtitle: '${Fmt.relativeDay(q.date)} · ${q.passengers} voyageur(s) · ${state.trips.length} départs',
          glow: ServiceType.bus.glow,
          scrollable: false,
          padding: EdgeInsets.zero,
          body: Column(
            children: [
              const SizedBox(height: 8),
              ChipRow(
                children: [
                  for (final s in TripSort.values)
                    WamiChip(label: s.label, selected: state.sort == s, onTap: () => cubit.setSort(s)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: switch (state.tripsStatus) {
                  LoadStatus.loading || LoadStatus.idle => const WamiLoading(label: 'Recherche des départs…'),
                  LoadStatus.failure =>
                    WamiErrorView(failure: state.failure ?? const UnexpectedFailure(), onRetry: cubit.search),
                  LoadStatus.ready when state.trips.isEmpty =>
                    const Center(child: Text('Aucun départ ce jour-là. Essayez une autre date.')),
                  LoadStatus.ready => ListView.separated(
                      padding: const EdgeInsets.fromLTRB(WamiSpace.screen, 0, WamiSpace.screen, 16),
                      itemCount: state.sortedTrips.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i == state.sortedTrips.length) {
                          return Text(
                            'Compagnies, horaires et prix : exemples à valider',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                          );
                        }
                        final trip = state.sortedTrips[i];
                        return TripCard(
                          trip: trip,
                          isBest: trip.id == best?.id,
                          inCompare: state.compareIds.contains(trip.id),
                          onToggleCompare: () => cubit.toggleCompare(trip.id),
                          onTap: () {
                            cubit.selectTrip(trip);
                            context.push(Routes.busSeats);
                          },
                        );
                      },
                    ),
                },
              ),
            ],
          ),
          bottom: GlassCard(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comparer (${state.compareIds.length}/${BusBookingState.maxCompared})',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        state.canCompare ? 'Ou touchez un départ pour réserver' : 'Cochez au moins 2 départs',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                WamiPrimaryButton(
                  label: 'Comparer',
                  expand: false,
                  height: 46,
                  onPressed: state.canCompare ? () => context.push(Routes.busCompare) : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

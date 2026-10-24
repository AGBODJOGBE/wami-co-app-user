import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/service_type.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/wami_colors.dart';
import '../../../../core/theme/wami_palette.dart';
import '../../../../core/theme/wami_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/load_status.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../domain/entities/bus.dart';
import '../cubit/bus_booking_cubit.dart';

/// Plan du bus interactif : un siège par voyageur.
class BusSeatPage extends StatelessWidget {
  const BusSeatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BusBookingCubit>();
    return BlocConsumer<BusBookingCubit, BusBookingState>(
      listenWhen: (a, b) => a.bookingStatus != b.bookingStatus || (b.failure != null && a.failure != b.failure),
      listener: (context, state) {
        if (state.failure != null) showWamiMessage(context, state.failure!.message);
        if (state.bookingStatus == LoadStatus.ready) context.pushReplacement(Routes.busTicket);
      },
      builder: (context, state) {
        final trip = state.selectedTrip;
        final pax = state.query.passengers;
        final missing = pax - state.seats.length;
        return WamiScreen(
          title: pax > 1 ? 'Choisissez vos $pax sièges' : 'Choisissez votre siège',
          subtitle: trip == null ? null : '${trip.company} · ${trip.departure} → ${trip.arrival}',
          glow: ServiceType.bus.glow,
          body: state.seatStatus == LoadStatus.loading || state.seatMap == null
              ? const SizedBox(height: 300, child: WamiLoading())
              : Gap(
                  children: [
                    const Row(
                      children: [
                        _Legend(label: 'Libre', kind: _SeatKind.free),
                        SizedBox(width: 14),
                        _Legend(label: 'Pris', kind: _SeatKind.taken),
                        SizedBox(width: 14),
                        _Legend(label: 'Le vôtre', kind: _SeatKind.mine),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(34), bottom: Radius.circular(20)),
                        border: Border.all(color: context.wami.glassBorder),
                        color: context.wami.glass,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text('AVANT DU BUS', style: Theme.of(context).textTheme.labelSmall),
                              const Spacer(),
                              Icon(Icons.radio_button_unchecked_rounded, color: context.wami.inkMuted),
                            ],
                          ),
                          const SizedBox(height: 10),
                          for (final row in state.seatMap!.rows)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Row(
                                children: [
                                  for (final seat in row)
                                    Expanded(
                                      child: seat == null
                                          ? const SizedBox(height: 30)
                                          : Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 3.5),
                                              child: _SeatButton(
                                                seat: seat,
                                                mine: state.seats.contains(seat.code),
                                                onTap: () => cubit.toggleSeat(seat),
                                              ),
                                            ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
          bottom: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sièges', style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        state.seats.isEmpty ? '—' : state.seats.join(', '),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Total', style: Theme.of(context).textTheme.bodySmall),
                      NumberText(Fmt.fcfa((trip?.price ?? 0) * pax), size: 19),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              WamiPrimaryButton(
                label: state.seatsComplete
                    ? 'Payer · ${Fmt.fcfa((trip?.price ?? 0) * pax)}'
                    : 'Encore $missing siège(s) à choisir',
                loading: state.bookingStatus == LoadStatus.loading,
                onPressed: state.seatsComplete ? cubit.book : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _SeatKind { free, taken, mine }

class _SeatButton extends StatelessWidget {
  const _SeatButton({required this.seat, required this.mine, required this.onTap});
  final Seat seat;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kind = seat.taken ? _SeatKind.taken : (mine ? _SeatKind.mine : _SeatKind.free);
    return Semantics(
      button: true,
      selected: mine,
      enabled: !seat.taken,
      label: 'Siège ${seat.code}${seat.taken ? ', pris' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: seat.taken ? null : onTap,
        child: AnimatedContainer(
          duration: WamiMotion.fast,
          height: 30,
          alignment: Alignment.center,
          decoration: _decoration(context, kind),
          child: Text(
            seat.code,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: switch (kind) {
                _SeatKind.mine => WamiColors.white,
                _SeatKind.taken => context.wami.ink.withValues(alpha: 0.18),
                _SeatKind.free => context.wami.inkMuted,
              },
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _decoration(BuildContext context, _SeatKind kind) {
  final p = context.wami;
  const shape = BorderRadius.vertical(top: Radius.circular(9), bottom: Radius.circular(6));
  return switch (kind) {
    _SeatKind.mine => BoxDecoration(
        borderRadius: shape,
        gradient: WamiEffects.ctaGradient,
        boxShadow: [BoxShadow(color: WamiColors.orange.withValues(alpha: 0.6), blurRadius: 12)],
      ),
    _SeatKind.taken => BoxDecoration(
        borderRadius: shape,
        color: p.ink.withValues(alpha: 0.02),
        border: Border.all(color: p.ink.withValues(alpha: 0.06)),
      ),
    _SeatKind.free => BoxDecoration(
        borderRadius: shape,
        color: p.ink.withValues(alpha: 0.06),
        border: Border.all(color: p.ink.withValues(alpha: 0.18)),
      ),
  };
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.kind});
  final String label;
  final _SeatKind kind;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 14, height: 14, decoration: _decoration(context, kind)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
      ],
    );
  }
}

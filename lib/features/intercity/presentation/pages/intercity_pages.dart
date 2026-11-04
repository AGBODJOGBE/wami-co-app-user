import 'dart:async';

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
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_live.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../../../core/widgets/wami_selectors.dart';
import '../../domain/entities/intercity.dart';
import '../cubit/intercity_cubit.dart';

final _glow = ServiceType.intercity.glow;

String _duration(IntercityOffer o) {
  final d = o.duration;
  return d == null || d.inMinutes <= 0 ? '' : Fmt.duration(d.inMinutes);
}

/// Étape 1 : villes, date et nombre de places.
class IntercitySearchPage extends StatelessWidget {
  const IntercitySearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<IntercityCubit>();
    final t = Theme.of(context).textTheme;
    final today = DateTime.now();
    final days = [for (var i = 0; i < 7; i++) DateTime(today.year, today.month, today.day + i)];

    return BlocBuilder<IntercityCubit, IntercityState>(
      builder: (context, state) {
        final q = state.query;
        return WamiScreen(
          title: 'Trajets interurbains',
          glow: _glow,
          onBack: () => context.go(Routes.home),
          body: Gap(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Réservez des places dans la voiture d’un chauffeur qui fait le trajet entre deux villes.',
                      style: t.bodySmall,
                    ),
                  ),
                  const ServiceIllustration(ServiceArt.auto, size: 96),
                ],
              ),
              GlassCard(
                padding: const EdgeInsets.all(12),
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    Column(
                      children: [
                        _CityField(
                          label: 'Départ',
                          city: q.from,
                          onTap: () => _pickCity(context, 'Ville de départ', q.from, cubit.setFrom),
                        ),
                        const SizedBox(height: 8),
                        _CityField(
                          label: 'Arrivée',
                          city: q.to,
                          highlight: true,
                          onTap: () => _pickCity(context, 'Ville d’arrivée', q.to, cubit.setTo),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: WamiIconButton(
                        icon: Icons.swap_vert_rounded,
                        tooltip: 'Inverser départ et arrivée',
                        color: _glow,
                        onPressed: cubit.swapCities,
                      ),
                    ),
                  ],
                ),
              ),
              const SectionLabel('Date'),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: days.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => WamiChip(
                    label: Fmt.relativeDay(days[i]),
                    selected: DateUtils.isSameDay(days[i], q.date),
                    onTap: () => cubit.setDate(days[i]),
                  ),
                ),
              ),
              GlassCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Places', style: t.titleSmall),
                          Text('Une place par voyageur', style: t.bodySmall),
                        ],
                      ),
                    ),
                    CounterStepper(value: q.seats, max: 4, label: 'place', onChanged: cubit.setSeats),
                  ],
                ),
              ),
            ],
          ),
          bottom: WamiPrimaryButton(
            label: 'Rechercher',
            onPressed: () {
              cubit.search();
              context.push(Routes.intercityResults);
            },
          ),
        );
      },
    );
  }
}

Future<void> _pickCity(BuildContext context, String title, String current, ValueChanged<String> onPicked) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) => WamiSheet(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final city in BeninCities.main)
              WamiChip(
                label: city,
                selected: city == current,
                onTap: () {
                  onPicked(city);
                  Navigator.of(sheet).pop();
                },
              ),
          ],
        ),
      ],
    ),
  );
}

class _CityField extends StatelessWidget {
  const _CityField({required this.label, required this.city, required this.onTap, this.highlight = false});
  final String label;
  final String city;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$label : $city',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.place_rounded, color: highlight ? _glow : Colors.white, size: 20),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: t.bodySmall?.copyWith(fontSize: 10.5)),
                  Text(city, style: t.titleSmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Étape 2 : les trajets publiés par des chauffeurs ce jour-là.
class IntercityResultsPage extends StatelessWidget {
  const IntercityResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<IntercityCubit>();
    return BlocConsumer<IntercityCubit, IntercityState>(
      listenWhen: (a, b) => b.failure != null && a.failure != b.failure && b.searchStatus != LoadStatus.failure,
      listener: (context, state) => showWamiMessage(context, state.failure!.message),
      builder: (context, state) {
        final q = state.query;
        return WamiScreen(
          title: '${q.from} → ${q.to}',
          subtitle: '${Fmt.relativeDay(q.date)} · ${q.seats} place(s)',
          glow: _glow,
          scrollable: false,
          padding: EdgeInsets.zero,
          body: switch (state.searchStatus) {
            LoadStatus.loading || LoadStatus.idle => const WamiLoading(label: 'Recherche des trajets…'),
            LoadStatus.failure =>
              WamiErrorView(failure: state.failure ?? const UnexpectedFailure(), onRetry: cubit.search),
            LoadStatus.ready when state.offers.isEmpty => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Aucun trajet ce jour-là. Essayez une autre date ou moins de places.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            LoadStatus.ready => ListView.separated(
                padding: const EdgeInsets.fromLTRB(WamiSpace.screen, 8, WamiSpace.screen, 16),
                itemCount: state.offers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final offer = state.offers[i];
                  return _OfferCard(
                    offer: offer,
                    onTap: () {
                      cubit.select(offer);
                      context.push(Routes.intercityOffer);
                    },
                  );
                },
              ),
          },
        );
      },
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.onTap});
  final IntercityOffer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final duration = _duration(offer);
    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NumberText(Fmt.hhmm(offer.departure), size: 20),
              if (offer.arrival != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded, size: 16),
                ),
                NumberText(Fmt.hhmm(offer.arrival!), size: 20),
              ],
              const Spacer(),
              NumberText(Fmt.fcfa(offer.pricePerSeat), size: 17),
              Text(' / place', style: t.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [offer.vehicle, if (duration.isNotEmpty) duration, '${offer.availableSeats} place(s) libre(s)'].join(' · '),
            style: t.bodySmall,
          ),
          if (offer.stops.isNotEmpty) Text('Étapes : ${offer.stops.join(', ')}', style: t.bodySmall),
        ],
      ),
    );
  }
}

/// Étape 3 : détail du trajet, places, mode de paiement.
class IntercityOfferPage extends StatelessWidget {
  const IntercityOfferPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<IntercityCubit>();
    final t = Theme.of(context).textTheme;
    return BlocConsumer<IntercityCubit, IntercityState>(
      listenWhen: (a, b) => a.bookingStatus != b.bookingStatus,
      listener: (context, state) {
        if (state.bookingStatus == LoadStatus.ready) context.pushReplacement(Routes.intercityBooked);
        if (state.bookingStatus == LoadStatus.failure && state.failure != null) {
          showWamiMessage(context, state.failure!.message);
        }
      },
      builder: (context, state) {
        final offer = state.selected;
        if (offer == null) return const Scaffold(body: WamiLoading());
        final duration = _duration(offer);
        return WamiScreen(
          title: '${offer.originCity} → ${offer.destinationCity}',
          subtitle: '${Fmt.dayMonth(offer.departure)} · ${Fmt.hhmm(offer.departure)}',
          glow: _glow,
          body: Gap(
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Stop(time: offer.departure, city: offer.originCity, address: offer.originAddress, start: true),
                    for (final stop in offer.stops) _Stop(city: stop),
                    _Stop(time: offer.arrival, city: offer.destinationCity, address: offer.destinationAddress),
                    const SizedBox(height: 8),
                    Text(
                      [offer.vehicle, if (duration.isNotEmpty) duration, offer.number]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: t.bodySmall,
                    ),
                    if (offer.description != null) ...[
                      const SizedBox(height: 6),
                      Text(offer.description!, style: t.bodyMedium),
                    ],
                  ],
                ),
              ),
              GlassCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Places', style: t.titleSmall),
                          Text('${offer.availableSeats} libre(s) sur ${offer.totalSeats}', style: t.bodySmall),
                        ],
                      ),
                    ),
                    CounterStepper(
                      value: state.seats,
                      max: offer.availableSeats < 1 ? 1 : offer.availableSeats,
                      label: 'place',
                      onChanged: cubit.setBookedSeats,
                    ),
                  ],
                ),
              ),
              const SectionLabel('Paiement'),
              for (final p in IntercityPayment.values)
                GlassCard(
                  onTap: () => cubit.setPayment(p),
                  borderColor: state.payment == p ? _glow : null,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [Text(p.label, style: t.titleSmall), Text(p.hint, style: t.bodySmall)],
                        ),
                      ),
                      Icon(
                        state.payment == p ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: state.payment == p ? _glow : null,
                      ),
                    ],
                  ),
                ),
              if (!offer.bookable)
                Text(
                  offer.availableSeats < 1
                      ? 'Ce trajet est complet.'
                      : 'Ce trajet ne peut pas encore être réservé depuis l’application.',
                  style: t.bodySmall,
                ),
            ],
          ),
          bottom: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text('Total', style: t.bodySmall),
                  const Spacer(),
                  NumberText(Fmt.fcfa(state.total), size: 19),
                ],
              ),
              const SizedBox(height: 12),
              WamiPrimaryButton(
                label: state.payment == IntercityPayment.wallet ? 'Réserver · ${Fmt.fcfa(state.total)}' : 'Réserver',
                loading: state.bookingStatus == LoadStatus.loading,
                onPressed: offer.bookable ? cubit.book : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.city, this.time, this.address, this.start = false});
  final String city;
  final DateTime? time;
  final String? address;
  final bool start;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 48, child: time == null ? null : NumberText(Fmt.hhmm(time!), size: 14)),
          Icon(start ? Icons.trip_origin_rounded : Icons.place_rounded, size: 16, color: _glow),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(city, style: t.titleSmall),
                if (address != null) Text(address!, style: t.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Étape 4 : réservation confirmée ; annulation possible tant qu'elle est confirmée.
class IntercityBookedPage extends StatelessWidget {
  const IntercityBookedPage({super.key});

  Future<void> _confirmCancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Annuler la réservation ?'),
        content: const Text('Vos places seront libérées. Un paiement par portefeuille vous est remboursé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Garder')),
          TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Annuler la réservation')),
        ],
      ),
    );
    if (ok == true && context.mounted) unawaited(context.read<IntercityCubit>().cancel());
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return BlocConsumer<IntercityCubit, IntercityState>(
      listenWhen: (a, b) => a.cancelStatus != b.cancelStatus,
      listener: (context, state) {
        if (state.cancelStatus == LoadStatus.failure && state.failure != null) {
          showWamiMessage(context, state.failure!.message);
        }
      },
      builder: (context, state) {
        final booking = state.booking;
        if (booking == null) return const Scaffold(body: WamiLoading());
        final offer = booking.offer;
        final cancelled = booking.status == IntercityBookingStatus.cancelled;
        return WamiScreen(
          title: cancelled ? 'Réservation annulée' : 'C’est réservé !',
          glow: _glow,
          showBack: false,
          body: Gap(
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Code de réservation'),
                    NumberText(booking.reference, size: 24),
                    Text('À donner au chauffeur au départ', style: t.bodySmall),
                  ],
                ),
              ),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${offer.originCity} → ${offer.destinationCity}', style: t.titleSmall),
                    Text('${Fmt.dayMonth(offer.departure)} · départ ${Fmt.hhmm(offer.departure)}', style: t.bodySmall),
                    if (offer.originAddress != null)
                      Text('Point de départ : ${offer.originAddress}', style: t.bodySmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('${booking.seats} place(s) · ${booking.payment.label}', style: t.bodySmall),
                        const Spacer(),
                        NumberText(Fmt.fcfa(booking.total), size: 17),
                      ],
                    ),
                  ],
                ),
              ),
              if (cancelled)
                Text(
                  (booking.refund ?? 0) > 0
                      ? '${Fmt.fcfa(booking.refund!)} vous sont remboursés dans votre portefeuille.'
                      : 'Aucun montant n’a été prélevé.',
                  style: t.bodyMedium,
                ),
            ],
          ),
          bottom: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!cancelled)
                WamiGhostButton(
                  label: 'Annuler la réservation',
                  onPressed: state.cancelStatus == LoadStatus.loading ? null : () => _confirmCancel(context),
                ),
              const SizedBox(height: 8),
              WamiPrimaryButton(label: 'Retour à l’accueil', onPressed: () => context.go(Routes.home)),
            ],
          ),
        );
      },
    );
  }
}

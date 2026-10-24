import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/service_type.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/wami_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/load_status.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../../../core/widgets/wami_selectors.dart';
import '../../domain/entities/lodging.dart';
import '../cubit/lodging_cubit.dart';
import '../widgets/lodging_widgets.dart';

/// Fiche hôtel / chambre : équipements et choix de la chambre.
class LodgingDetailPage extends StatelessWidget {
  const LodgingDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LodgingCubit>();
    final t = Theme.of(context).textTheme;
    return BlocBuilder<LodgingCubit, LodgingState>(
      builder: (context, state) {
        final l = state.selected;
        if (l == null) return const Scaffold(body: WamiLoading());
        return WamiScreen(
          title: l.name,
          subtitle: l.area,
          glow: ServiceType.lodging.glow,
          actions: [RatingText(l.rating, size: 14)],
          body: Gap(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(WamiRadius.xl),
                child: LodgingHero(lodging: l, height: 200, artSize: 180),
              ),
              AmenityRow(amenities: l.amenities),
              const SectionLabel('Choisir une chambre'),
              if (state.rooms.isEmpty)
                const SizedBox(height: 120, child: WamiLoading())
              else
                for (final r in state.rooms)
                  WamiOptionTile(
                    title: r.name,
                    subtitle: r.description,
                    selected: state.room?.id == r.id,
                    onTap: () => cubit.selectRoom(r.id),
                    trailing: NumberText(Fmt.fcfa(r.pricePerNight), size: 14),
                  ),
            ],
          ),
          bottom: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text('${state.search.nights} nuits · ${state.search.guests} pers.', style: t.bodySmall),
                  const Spacer(),
                  NumberText(Fmt.fcfa(state.total), size: 18),
                ],
              ),
              const SizedBox(height: 12),
              WamiPrimaryButton(
                label: 'Réserver',
                onPressed: state.room == null ? null : () => context.push(Routes.stayConfirm),
              ),
            ],
          ),
        );
      },
    );
  }
}

class LodgingConfirmPage extends StatelessWidget {
  const LodgingConfirmPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LodgingCubit>();
    final t = Theme.of(context).textTheme;
    return BlocConsumer<LodgingCubit, LodgingState>(
      listenWhen: (a, b) => a.bookingStatus != b.bookingStatus,
      listener: (context, state) {
        if (state.bookingStatus == LoadStatus.ready) context.pushReplacement(Routes.stayBooked);
        if (state.failure != null) showWamiMessage(context, state.failure!.message);
      },
      builder: (context, state) {
        final l = state.selected!;
        final room = state.room!;
        return WamiScreen(
          title: 'Confirmer',
          glow: ServiceType.lodging.glow,
          body: Gap(
            children: [
              GlassCard(
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(width: 64, child: LodgingHero(lodging: l, height: 64, artSize: 58)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.name, style: t.titleSmall),
                          Text('${room.name} · ${state.search.guests} pers.', style: t.bodySmall),
                          Text('${state.search.nights} nuits', style: t.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              GlassCard(
                child: Column(
                  children: [
                    _Line('${room.name} × ${state.search.nights} nuits', Fmt.fcfa(state.total)),
                    const _Line('Frais de service', '[à valider]'),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Text('Total', style: t.titleSmall),
                        const Spacer(),
                        NumberText(Fmt.fcfa(state.total), size: 17),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionLabel('Paiement'),
              for (final m in PaymentMethod.values)
                WamiOptionTile(
                  title: m.label,
                  subtitle: m.hint,
                  selected: state.payment == m,
                  onTap: () => cubit.selectPayment(m),
                ),
              Text(
                'Annulation gratuite jusqu’à [délai à valider] avant l’arrivée.',
                style: t.bodySmall?.copyWith(fontSize: 11.5),
              ),
            ],
          ),
          bottom: WamiPrimaryButton(
            label:
                state.payment == PaymentMethod.onSite ? 'Confirmer la réservation' : 'Payer · ${Fmt.fcfa(state.total)}',
            loading: state.bookingStatus == LoadStatus.loading,
            onPressed: cubit.book,
          ),
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [Text(label, style: t.bodySmall), const Spacer(), Text(value, style: t.labelLarge)]),
    );
  }
}

class LodgingBookedPage extends StatelessWidget {
  const LodgingBookedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<LodgingCubit>().state.booking;
    if (booking == null) return const Scaffold(body: WamiLoading());
    return WamiScreen(
      showBack: false,
      glow: ServiceType.lodging.glow,
      body: WamiSuccessView(
        icon: Icons.key_rounded,
        title: 'C’est réservé !',
        message: '${booking.lodging.name} vous attend · ${booking.nights} nuits',
        children: [
          GlassCard(
            child: Column(
              children: [
                const SectionLabel('Code de réservation'),
                const SizedBox(height: 6),
                NumberText(booking.reference, size: 22),
                Text('À présenter à la réception', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            onTap: () => context.go(Routes.ride, extra: booking.lodging.name),
            child: Row(
              children: [
                const IconBadge(Icons.local_taxi_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Une course jusqu’à l’hôtel ?', style: Theme.of(context).textTheme.titleSmall),
                      Text('Adresse déjà remplie', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ],
      ),
      bottom: WamiPrimaryButton(label: 'Retour à l’accueil', onPressed: () => context.go(Routes.home)),
    );
  }
}

/// Fiche appartement : caractéristiques et choix d'un créneau de visite.
class ApartmentPage extends StatelessWidget {
  const ApartmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LodgingCubit>();
    final t = Theme.of(context).textTheme;
    return BlocConsumer<LodgingCubit, LodgingState>(
      listenWhen: (a, b) => a.visitStatus != b.visitStatus,
      listener: (context, state) {
        if (state.visitStatus == LoadStatus.ready) context.pushReplacement(Routes.stayVisitSent);
        if (state.failure != null) showWamiMessage(context, state.failure!.message);
      },
      builder: (context, state) {
        final l = state.selected;
        if (l == null) return const Scaffold(body: WamiLoading());
        final slot = state.slot;
        return WamiScreen(
          title: l.name,
          subtitle: l.area,
          glow: ServiceType.lodging.glow,
          body: Gap(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(WamiRadius.xl),
                child: LodgingHero(
                  lodging: l,
                  height: 190,
                  artSize: 170,
                  child: l.verified
                      ? const Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(padding: EdgeInsets.all(14), child: WamiTag('Vérifié par WAMI')),
                        )
                      : null,
                ),
              ),
              Row(
                children: [
                  Text('Loyer', style: t.bodySmall),
                  const Spacer(),
                  NumberText(Fmt.fcfa(l.price), size: 17),
                  Text(' / mois', style: t.bodySmall),
                ],
              ),
              AmenityRow(amenities: l.amenities),
              Text(
                'Caution et avance : [conditions à valider avec le propriétaire]',
                style: t.bodySmall?.copyWith(fontSize: 11.5),
              ),
              const SectionLabel('Planifier une visite'),
              if (state.slots.isEmpty)
                const SizedBox(height: 120, child: WamiLoading())
              else
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.7,
                  children: [
                    for (final s in state.slots)
                      SlotButton(slot: s, selected: s.id == state.slotId, onTap: () => cubit.selectSlot(s)),
                  ],
                ),
            ],
          ),
          bottom: WamiPrimaryButton(
            label: slot == null ? 'Choisissez un créneau' : 'Demander la visite · ${slot.day} ${slot.time}',
            loading: state.visitStatus == LoadStatus.loading,
            onPressed: slot == null ? null : cubit.askVisit,
          ),
        );
      },
    );
  }
}

class VisitSentPage extends StatelessWidget {
  const VisitSentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final slot = context.watch<LodgingCubit>().state.slot;
    return WamiScreen(
      showBack: false,
      glow: ServiceType.lodging.glow,
      body: WamiSuccessView(
        positive: true,
        icon: Icons.check_rounded,
        title: 'Demande envoyée',
        message: 'Le propriétaire confirme votre visite${slot == null ? '' : ' du ${slot.day} à ${slot.time}'}. '
            'Vous recevrez une notification.',
        children: [
          GlassCard(
            child: Row(
              children: [
                WamiTag('Astuce', tint: ServiceType.lodging.glow),
                const SizedBox(width: 10),
                const Expanded(child: Text('Réservez une course le jour de la visite, l’adresse sera déjà remplie.')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          WamiGhostButton(
            label: 'Réserver une course',
            icon: Icons.local_taxi_rounded,
            onPressed: () => context.go(Routes.ride),
          ),
        ],
      ),
      bottom: WamiPrimaryButton(label: 'Retour à l’accueil', onPressed: () => context.go(Routes.home)),
    );
  }
}

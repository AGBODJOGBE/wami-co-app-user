import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/service_type.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../../../core/widgets/wami_selectors.dart';
import '../../../../core/widgets/wami_text_field.dart';
import '../../domain/entities/delivery.dart';
import '../cubit/delivery_cubit.dart';

/// Étape 1 : envoyer ou faire récupérer, adresses et contact.
class DeliveryAddressPage extends StatelessWidget {
  const DeliveryAddressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DeliveryCubit>();
    return BlocConsumer<DeliveryCubit, DeliveryState>(
      listenWhen: (a, b) => b.failure != null && a.failure != b.failure,
      listener: (context, state) => showWamiMessage(context, state.failure!.message),
      builder: (context, state) {
        final d = state.draft;
        final sending = d.mode == DeliveryMode.send;
        return WamiScreen(
          title: 'Livraison',
          glow: ServiceType.delivery.glow,
          onBack: () => context.go(Routes.home),
          body: Gap(
            children: [
              Text(
                'Un colis à envoyer ou à faire récupérer, partout en ville.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              WamiSegmented<DeliveryMode>(
                options: const [(DeliveryMode.send, 'Envoyer'), (DeliveryMode.pickup, 'Faire récupérer')],
                value: d.mode,
                onChanged: (m) => cubit.update((d) => d.copyWith(mode: m)),
              ),
              GlassCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    WamiTextField(
                      hint: sending ? 'Collecte · ma position' : 'Adresse de collecte',
                      icon: Icons.trip_origin_rounded,
                      initialValue: d.pickupAddress,
                      onChanged: (v) => cubit.update((d) => d.copyWith(pickupAddress: v)),
                    ),
                    const SizedBox(height: 8),
                    WamiTextField(
                      hint: sending ? 'Adresse de livraison' : 'Livraison · ma position',
                      icon: Icons.place_rounded,
                      initialValue: d.dropoffAddress,
                      onChanged: (v) => cubit.update((d) => d.copyWith(dropoffAddress: v)),
                    ),
                  ],
                ),
              ),
              SectionLabel(d.contactRole),
              WamiTextField(
                hint: 'Nom',
                icon: Icons.person_outline_rounded,
                initialValue: d.contactName,
                onChanged: (v) => cubit.update((d) => d.copyWith(contactName: v)),
              ),
              WamiTextField(
                hint: 'Téléphone',
                prefixText: '+229 ',
                keyboardType: TextInputType.phone,
                initialValue: d.contactPhone,
                onChanged: (v) => cubit.update((d) => d.copyWith(contactPhone: v)),
                suffix: IconButton(
                  tooltip: 'Choisir dans mes contacts',
                  icon: const Icon(Icons.contacts_outlined),
                  onPressed: () => showWamiMessage(context, 'Accès aux contacts : à brancher'),
                ),
              ),
              Row(
                children: [
                  WamiChip(
                    label: 'Maintenant',
                    icon: Icons.schedule_rounded,
                    selected: !d.scheduled,
                    onTap: () => cubit.update((d) => d.copyWith(scheduled: false, clearScheduledAt: true)),
                  ),
                  const SizedBox(width: 8),
                  WamiChip(
                    label: 'Programmer',
                    selected: d.scheduled,
                    onTap: () => cubit.update((d) => d.copyWith(scheduled: true)),
                  ),
                ],
              ),
              if (d.scheduled)
                WamiOptionTile(
                  title: d.scheduledAt == null
                      ? 'Choisir la date et l’heure'
                      : '${Fmt.relativeDay(d.scheduledAt!)} · ${Fmt.hhmm(d.scheduledAt!)}',
                  subtitle: 'Au moins 15 minutes à l’avance',
                  selected: d.scheduledAt != null,
                  onTap: () => _pickDateTime(context, cubit, d.scheduledAt),
                  leading: const IconBadge(Icons.event_rounded),
                ),
            ],
          ),
          bottom: WamiPrimaryButton(
            label: 'Continuer',
            onPressed: () {
              if (cubit.submitAddresses()) context.push(Routes.deliveryParcel);
            },
          ),
        );
      },
    );
  }
}

/// Date puis heure de la livraison programmée.
Future<void> _pickDateTime(BuildContext context, DeliveryCubit cubit, DateTime? current) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: current ?? now,
    firstDate: now,
    lastDate: now.add(const Duration(days: 30)),
  );
  if (date == null || !context.mounted) return;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(current ?? now.add(const Duration(hours: 1))),
  );
  if (time == null) return;
  final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  cubit.update((d) => d.copyWith(scheduledAt: at));
}

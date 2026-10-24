import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/service_type.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/wami_colors.dart';
import '../../../../core/theme/wami_palette.dart';
import '../../../../core/theme/wami_tokens.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../../../core/widgets/wami_selectors.dart';
import '../../../../core/widgets/wami_text_field.dart';
import '../../domain/entities/delivery.dart';
import '../cubit/delivery_cubit.dart';

/// Étape 2 : taille du colis et options.
class DeliveryParcelPage extends StatelessWidget {
  const DeliveryParcelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DeliveryCubit>();
    return BlocBuilder<DeliveryCubit, DeliveryState>(
      builder: (context, state) {
        final d = state.draft;
        return WamiScreen(
          title: 'Votre colis',
          glow: ServiceType.delivery.glow,
          body: Gap(
            children: [
              const SectionLabel('Taille'),
              Row(
                children: [
                  for (final size in ParcelSize.values) ...[
                    Expanded(
                      child: _SizeCard(size: size, selected: d.size == size, onTap: () => cubit.setSize(size)),
                    ),
                    if (size != ParcelSize.large) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SectionLabel('Options'),
              GlassGroup(
                children: [
                  ToggleRow(
                    title: 'Fragile',
                    subtitle: 'Le coursier manipule avec soin',
                    value: d.fragile,
                    onChanged: (v) => cubit.update((d) => d.copyWith(fragile: v)),
                  ),
                  ToggleRow(
                    title: 'Encaisser à la livraison',
                    subtitle: 'Le coursier récupère l’argent pour vous',
                    value: d.cashOnDelivery,
                    onChanged: (v) => cubit.update((d) => d.copyWith(cashOnDelivery: v)),
                  ),
                  if (d.cashOnDelivery)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                      child: WamiTextField(
                        hint: 'Montant à encaisser (F CFA)',
                        keyboardType: TextInputType.number,
                        initialValue: d.cashAmount == 0 ? '' : '${d.cashAmount}',
                        onChanged: (v) => cubit.update((d) => d.copyWith(cashAmount: int.tryParse(v) ?? 0)),
                      ),
                    ),
                  ListTile(
                    title: const Text('Photo du colis'),
                    subtitle: const Text('Facultatif, rassure le destinataire'),
                    trailing: Icon(Icons.photo_camera_outlined, color: context.wami.orangeStrong),
                    onTap: () => showWamiMessage(context, 'Appareil photo : à brancher (image_picker)'),
                  ),
                ],
              ),
            ],
          ),
          bottom: WamiPrimaryButton(
            label: 'Voir le prix',
            onPressed: () {
              cubit.loadQuotes();
              context.push(Routes.deliveryQuote);
            },
          ),
        );
      },
    );
  }
}

class _SizeCard extends StatelessWidget {
  const _SizeCard({required this.size, required this.selected, required this.onTap});
  final ParcelSize size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final art = switch (size) {
      ParcelSize.small => 46.0,
      ParcelSize.medium => 60.0,
      ParcelSize.large => 76.0,
    };
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: WamiMotion.base,
          height: 140,
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WamiRadius.lg),
            color: context.wami.glass,
            gradient: selected
                ? RadialGradient(
                    center: Alignment.topCenter,
                    colors: [WamiColors.orange.withValues(alpha: 0.3), WamiColors.orange.withValues(alpha: 0)],
                  )
                : null,
            border:
                Border.all(color: selected ? WamiColors.orangeLight.withValues(alpha: 0.85) : context.wami.glassBorder),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ServiceIllustration(ServiceArt.colis, size: art),
              Text(size.label, style: t.titleSmall),
              Text(
                size.examples,
                style: t.bodySmall?.copyWith(fontSize: 10.5),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/service_type.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/load_status.dart';
import '../../../../core/widgets/route_map_view.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_live.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../../../core/widgets/wami_selectors.dart';
import '../../domain/entities/delivery.dart';
import '../cubit/delivery_cubit.dart';

/// Étape 3 : mode de livraison, qui paie, confirmation.
class DeliveryQuotePage extends StatelessWidget {
  const DeliveryQuotePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DeliveryCubit>();
    return Scaffold(
      body: BlocConsumer<DeliveryCubit, DeliveryState>(
        listenWhen: (a, b) => a.orderStatus != b.orderStatus || (b.failure != null && a.failure != b.failure),
        listener: (context, state) {
          if (state.failure != null) showWamiMessage(context, state.failure!.message);
          if (state.orderStatus == LoadStatus.ready) context.pushReplacement(Routes.deliveryTrack);
        },
        builder: (context, state) {
          final d = state.draft;
          final quote = state.selectedQuote;
          return Stack(
            children: [
              const Positioned(left: 0, right: 0, top: 0, height: 460, child: RouteMapView()),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      WamiIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        tooltip: 'Retour',
                        onPressed: () => context.pop(),
                      ),
                      const Spacer(),
                      StatusPill(child: Text('Colis ${d.size.label.toLowerCase()}')),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: WamiSheet(
                  children: [
                    Text('Mode de livraison', style: Theme.of(context).textTheme.titleMedium),
                    Text('Proposé selon la taille de votre colis', style: Theme.of(context).textTheme.bodySmall),
                    if (state.quotesStatus == LoadStatus.loading)
                      const SizedBox(height: 120, child: WamiLoading())
                    else
                      for (final q in state.quotes)
                        WamiOptionTile(
                          showRadio: false,
                          selected: q.vehicle == d.vehicle,
                          onTap: () => cubit.update((d) => d.copyWith(vehicle: q.vehicle)),
                          leading: ServiceIllustration(
                            q.vehicle == DeliveryVehicle.moto ? ServiceArt.moto : ServiceArt.auto,
                            size: 46,
                          ),
                          title: q.vehicle.label,
                          subtitle: 'Livré en ~${q.etaMinutes} min',
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (q.suitable) ...[const WamiTag('Adapté'), const SizedBox(width: 8)],
                              NumberText(Fmt.fcfa(q.price), size: 14),
                            ],
                          ),
                        ),
                    const SectionLabel('Qui paie la livraison ?'),
                    WamiSegmented<DeliveryPayer>(
                      options: const [(DeliveryPayer.sender, 'Moi'), (DeliveryPayer.recipient, 'Le destinataire')],
                      value: d.payer,
                      onChanged: (p) => cubit.update((d) => d.copyWith(payer: p)),
                    ),
                    WamiPrimaryButton(
                      label: quote == null ? 'Confirmer l’envoi' : 'Confirmer l’envoi · ${Fmt.fcfa(quote.price)}',
                      loading: state.orderStatus == LoadStatus.loading,
                      onPressed: quote == null ? null : cubit.confirm,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

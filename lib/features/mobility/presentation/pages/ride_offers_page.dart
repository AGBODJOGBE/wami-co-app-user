import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/load_status.dart';
import '../../../../core/widgets/route_map_view.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_live.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../../../core/widgets/wami_selectors.dart';
import '../bloc/ride_bloc.dart';
import '../widgets/ride_widgets.dart';

/// Étape 2 : prix par véhicule et commande.
class RideOffersPage extends StatelessWidget {
  const RideOffersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<RideBloc, RideState>(
        listenWhen: (a, b) => a.bookingStatus != b.bookingStatus || b.failure != null,
        listener: (context, state) {
          if (state.failure != null) showWamiMessage(context, state.failure!.message);
          if (state.bookingStatus == LoadStatus.ready) context.pushReplacement(Routes.rideTrack);
        },
        builder: (context, state) {
          final offer = state.selectedOffer;
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
                      StatusPill(child: Text(state.destination?.name ?? '')),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: WamiSheet(
                  children: [
                    Text('Choisissez votre véhicule', style: Theme.of(context).textTheme.titleMedium),
                    if (state.offersStatus == LoadStatus.loading)
                      const SizedBox(height: 180, child: WamiLoading(label: 'Calcul des prix…'))
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: state.offers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final o = state.offers[i];
                            return OfferTile(
                              offer: o,
                              selected: o.category == state.selected,
                              onTap: () => context.read<RideBloc>().add(RideCategorySelected(o.category)),
                            );
                          },
                        ),
                      ),
                    Row(
                      children: [
                        WamiChip(
                          label: 'Portefeuille',
                          icon: Icons.account_balance_wallet_outlined,
                          selected: true,
                          onTap: () {},
                        ),
                        const SizedBox(width: 8),
                        WamiChip(label: 'Code promo', icon: Icons.local_offer_outlined, selected: false, onTap: () {}),
                      ],
                    ),
                    WamiPrimaryButton(
                      label:
                          offer == null ? 'Commander' : 'Commander ${offer.category.label} · ${Fmt.fcfa(offer.price)}',
                      loading: state.bookingStatus == LoadStatus.loading,
                      onPressed: offer == null ? null : () => context.read<RideBloc>().add(const RideBooked()),
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

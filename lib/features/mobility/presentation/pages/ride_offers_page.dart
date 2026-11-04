import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/load_status.dart';
import '../../../../core/widgets/route_map_view.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_text_field.dart';
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
        listenWhen: (a, b) => a.bookingStatus != b.bookingStatus || b.failure != null || b.promoError != null,
        listener: (context, state) {
          if (state.failure != null) showWamiMessage(context, state.failure!.message);
          if (state.promoError != null) showWamiMessage(context, state.promoError!);
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
                        WamiChip(
                          label: state.promoCode ?? 'Code promo',
                          icon:
                              state.promoCode == null ? Icons.local_offer_outlined : Icons.check_circle_outline_rounded,
                          selected: state.promoCode != null,
                          onTap: () => _showPromoSheet(context),
                        ),
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

/// Saisie d'un code promo, avec les codes que le passager peut utiliser.
Future<void> _showPromoSheet(BuildContext context) {
  final bloc = context.read<RideBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(value: bloc, child: const _PromoSheet()),
  );
}

class _PromoSheet extends StatefulWidget {
  const _PromoSheet();

  @override
  State<_PromoSheet> createState() => _PromoSheetState();
}

class _PromoSheetState extends State<_PromoSheet> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _apply(String code) {
    final value = code.trim();
    if (value.isEmpty) return;
    context.read<RideBloc>().add(RidePromoApplied(value));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RideBloc>().state;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: WamiSheet(
        children: [
          Text('Code promo', style: t.titleMedium),
          if (state.promoCode != null)
            Row(
              children: [
                Expanded(child: Text('Code appliqué : ${state.promoCode}', style: t.bodyMedium)),
                WamiGhostButton(
                  label: 'Retirer',
                  onPressed: () {
                    context.read<RideBloc>().add(const RidePromoRemoved());
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          WamiTextField(
            hint: 'Saisissez votre code',
            label: 'Code promo',
            icon: Icons.local_offer_outlined,
            controller: _code,
            autofocus: true,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]'))],
            onSubmitted: _apply,
          ),
          if (state.availablePromos.isNotEmpty) ...[
            Text('Vos codes', style: t.labelLarge),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final promo in state.availablePromos)
                  WamiChip(
                    label: promo.displayText.isEmpty ? promo.code : '${promo.code} · ${promo.displayText}',
                    selected: promo.code == state.promoCode,
                    onTap: () => _apply(promo.code),
                  ),
              ],
            ),
          ],
          WamiPrimaryButton(label: 'Appliquer', onPressed: () => _apply(_code.text)),
        ],
      ),
    );
  }
}

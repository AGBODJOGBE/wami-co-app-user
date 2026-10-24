import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/service_type.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/wami_tokens.dart';
import '../../../../core/utils/load_status.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../../../core/widgets/wami_selectors.dart';
import '../../domain/entities/lodging.dart';
import '../cubit/lodging_cubit.dart';
import '../widgets/lodging_widgets.dart';

/// Recherche : le formulaire s'adapte au type (nuitées ou location au mois).
class LodgingSearchPage extends StatelessWidget {
  const LodgingSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LodgingCubit>();
    final t = Theme.of(context).textTheme;
    return BlocBuilder<LodgingCubit, LodgingState>(
      builder: (context, state) {
        final s = state.search;
        final monthly = s.type.isMonthly;
        final priorities = monthly
            ? const [Amenity.furnished, Amenity.security, Amenity.runningWater, Amenity.parking]
            : const [Amenity.airConditioning, Amenity.wifi, Amenity.generator, Amenity.parking];
        return WamiScreen(
          title: 'Hébergement',
          glow: ServiceType.lodging.glow,
          onBack: () => context.go(Routes.home),
          body: Gap(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      monthly
                          ? 'Louez au mois, visitez avant de vous engager.'
                          : 'Réservez une nuit ou plus, payez en un geste.',
                      style: t.bodySmall,
                    ),
                  ),
                  ServiceIllustration(artFor(s.type), size: 96),
                ],
              ),
              WamiSegmented<LodgingType>(
                options: [for (final type in LodgingType.values) (type, type.label)],
                value: s.type,
                onChanged: cubit.setType,
              ),
              GlassCard(
                child: Row(
                  children: [
                    const IconBadge(Icons.place_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Où ?', style: t.bodySmall),
                          Text(s.city, style: t.titleSmall),
                        ],
                      ),
                    ),
                    WamiTag(monthly ? 'Ma ville' : 'Selon votre billet', tint: ServiceType.lodging.glow),
                  ],
                ),
              ),
              GlassCard(
                child: Row(
                  children: [
                    const IconBadge(Icons.calendar_month_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(monthly ? 'Emménagement' : 'Arrivée → départ', style: t.bodySmall),
                          Text(
                            monthly ? 'À partir du [date]' : '[Arrivée] → [Départ] · ${s.nights} nuits',
                            style: t.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!monthly)
                GlassCard(
                  child: Row(
                    children: [
                      Expanded(child: Text('Personnes', style: t.titleSmall)),
                      CounterStepper(value: s.guests, label: 'personne', onChanged: cubit.setGuests),
                    ],
                  ),
                ),
              const SectionLabel('Vos priorités'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in priorities)
                    WamiChip(label: a.label, selected: s.priorities.contains(a), onTap: () => cubit.togglePriority(a)),
                ],
              ),
            ],
          ),
          bottom: WamiPrimaryButton(
            label: monthly ? 'Voir les appartements' : 'Rechercher',
            onPressed: () {
              cubit.runSearch();
              context.push(Routes.stayResults);
            },
          ),
        );
      },
    );
  }
}

class LodgingResultsPage extends StatelessWidget {
  const LodgingResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LodgingCubit>();
    return BlocBuilder<LodgingCubit, LodgingState>(
      builder: (context, state) {
        final s = state.search;
        return WamiScreen(
          title: '${s.type.plural} · ${s.city}',
          subtitle: s.type.isMonthly ? 'Location au mois' : '${s.nights} nuits · ${s.guests} pers.',
          glow: ServiceType.lodging.glow,
          scrollable: false,
          padding: EdgeInsets.zero,
          body: switch (state.resultsStatus) {
            LoadStatus.loading || LoadStatus.idle => const WamiLoading(label: 'Recherche des meilleures adresses…'),
            LoadStatus.failure => WamiErrorView(failure: state.failure!, onRetry: cubit.runSearch),
            LoadStatus.ready => ListView.separated(
                padding: const EdgeInsets.fromLTRB(WamiSpace.screen, 8, WamiSpace.screen, 24),
                itemCount: state.results.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  if (i == state.results.length) {
                    return Text(
                      'Établissements et prix : exemples à valider',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                    );
                  }
                  final l = state.results[i];
                  return LodgingCard(
                    lodging: l,
                    topPick: i == 0,
                    favorite: state.favorites.contains(l.id),
                    onFavorite: () => cubit.toggleFavorite(l.id),
                    onTap: () {
                      cubit.open(l);
                      context.push(l.type.isMonthly ? Routes.stayApartment : Routes.stayDetail);
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

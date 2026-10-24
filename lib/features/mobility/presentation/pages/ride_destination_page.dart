import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/service_type.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/wami_colors.dart';
import '../../../../core/theme/wami_palette.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../../../core/widgets/wami_text_field.dart';
import '../../domain/entities/place.dart';
import '../bloc/ride_bloc.dart';

/// Étape 1 : choix de la destination (départ = position actuelle).
class RideDestinationPage extends StatefulWidget {
  const RideDestinationPage({super.key, this.initialQuery});
  final String? initialQuery;

  @override
  State<RideDestinationPage> createState() => _RideDestinationPageState();
}

class _RideDestinationPageState extends State<RideDestinationPage> {
  late final _to = TextEditingController(text: widget.initialQuery);

  @override
  void initState() {
    super.initState();
    context.read<RideBloc>().add(RideStarted(initialQuery: widget.initialQuery));
  }

  @override
  void dispose() {
    _to.dispose();
    super.dispose();
  }

  void _choose(Place place) {
    context.read<RideBloc>().add(RideDestinationChosen(place));
    context.push(Routes.rideOffers);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return WamiScreen(
      title: 'Où allez-vous ?',
      glow: ServiceType.mobility.glow,
      onBack: () => context.go(Routes.home),
      body: BlocBuilder<RideBloc, RideState>(
        buildWhen: (a, b) => a.suggestions != b.suggestions || a.query != b.query,
        builder: (context, state) {
          return Gap(
            children: [
              GlassCard(
                padding: const EdgeInsets.all(12),
                child: RouteFields(
                  fromHint: 'Départ · ma position',
                  toHint: 'Destination',
                  toController: _to,
                  autofocusTo: widget.initialQuery == null,
                  onToChanged: (q) => context.read<RideBloc>().add(RideQueryChanged(q)),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 16, color: context.wami.orangeStrong),
                  const SizedBox(width: 6),
                  Text('Suggestions selon vos habitudes', style: t.bodySmall),
                ],
              ),
              if (state.query.length >= 2 && state.suggestions.isEmpty)
                Text('Aucun lieu trouvé pour « ${state.query} ».', style: t.bodySmall),
              GlassGroup(
                children: [
                  for (final place in state.suggestions)
                    ListTile(
                      leading: const IconBadge(Icons.place_rounded),
                      title: Text(place.name, style: t.titleSmall),
                      subtitle: Text(place.address, style: t.bodySmall),
                      onTap: () => _choose(place),
                    ),
                  if (state.suggestions.isEmpty)
                    ListTile(
                      leading: const IconBadge(Icons.map_rounded, color: WamiColors.glowLivraison),
                      title: Text('Choisir sur la carte', style: t.titleSmall),
                      subtitle: Text('Déplacez le repère à l’endroit exact', style: t.bodySmall),
                      onTap: () => _choose(const Place(id: 'map', name: 'Point sur la carte', address: '[Adresse]')),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

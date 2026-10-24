import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/wami_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/load_status.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../../../core/widgets/wami_selectors.dart';
import '../bloc/ride_bloc.dart';

/// Étape 4 : récapitulatif et note. Le paiement a déjà été prélevé à l'arrivée.
class RideRatingPage extends StatefulWidget {
  const RideRatingPage({super.key});

  @override
  State<RideRatingPage> createState() => _RideRatingPageState();
}

class _RideRatingPageState extends State<RideRatingPage> {
  int _stars = 5;
  final _tags = <String>{'Conduite sûre', 'Ponctuel'};

  static const _allTags = ['Conduite sûre', 'Ponctuel', 'Véhicule propre', 'Sympathique', 'Bon itinéraire'];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return BlocConsumer<RideBloc, RideState>(
      listenWhen: (a, b) => a.ratingStatus != b.ratingStatus,
      listener: (context, state) {
        if (state.ratingStatus == LoadStatus.ready) {
          showWamiMessage(context, 'Merci pour votre note !');
          context.go(Routes.home);
        }
        if (state.failure != null) showWamiMessage(context, state.failure!.message);
      },
      builder: (context, state) {
        final ride = state.ride;
        if (ride == null) return const Scaffold(body: WamiLoading());
        final total = ride.total;
        return WamiScreen(
          title: 'Vous êtes arrivé',
          showBack: false,
          body: Gap(
            children: [
              GlassCard(
                child: Column(
                  children: [
                    _line(context, 'Course ${ride.category.label}', ride.fare),
                    if (ride.waitingFee > 0) _line(context, 'Attente', ride.waitingFee),
                    if (ride.pauseFee > 0) _line(context, 'Pause', ride.pauseFee),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Text('Total payé', style: t.titleSmall),
                        const Spacer(),
                        NumberText(Fmt.fcfa(total), size: 18, glow: true),
                      ],
                    ),
                  ],
                ),
              ),
              if (ride.driver != null)
                Center(
                  child: Text(
                    'Comment s’est passée la course avec ${ride.driver!.name} ?',
                    style: t.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      tooltip: '$i étoile${i > 1 ? 's' : ''}',
                      iconSize: 38,
                      onPressed: () => setState(() => _stars = i),
                      icon: Icon(
                        i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: i <= _stars ? WamiColors.orangeLight : WamiColors.white.withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in _allTags)
                    WamiChip(
                      label: tag,
                      selected: _tags.contains(tag),
                      onTap: () => setState(() => _tags.contains(tag) ? _tags.remove(tag) : _tags.add(tag)),
                    ),
                ],
              ),
            ],
          ),
          bottom: WamiPrimaryButton(
            label: 'Envoyer ma note',
            loading: state.ratingStatus == LoadStatus.loading,
            onPressed: () => context.read<RideBloc>().add(RideRated(stars: _stars, tags: {..._tags})),
          ),
        );
      },
    );
  }

  Widget _line(BuildContext context, String label, int amount) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: t.bodySmall),
          const Spacer(),
          Text(Fmt.fcfa(amount), style: t.labelLarge),
        ],
      ),
    );
  }
}

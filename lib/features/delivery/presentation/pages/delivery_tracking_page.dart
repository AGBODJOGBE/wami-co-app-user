import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/wami_colors.dart';
import '../../../../core/theme/wami_palette.dart';
import '../../../../core/theme/wami_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/load_status.dart';
import '../../../../core/widgets/route_map_view.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_live.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../domain/entities/delivery.dart';
import '../cubit/delivery_cubit.dart';

/// Étape 4 : suivi du colis jusqu'à la remise avec code.
class DeliveryTrackingPage extends StatelessWidget {
  const DeliveryTrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<DeliveryCubit, DeliveryState>(
        // Livraison annulée ou interrompue : on prévient puis on revient à l'accueil.
        listenWhen: (a, b) => b.failure != null && a.failure != b.failure && b.orderStatus == LoadStatus.ready,
        listener: (context, state) {
          showWamiMessage(context, state.failure!.message);
          context.go(Routes.home);
        },
        builder: (context, state) {
          final tr = state.tracking;
          if (tr == null) return const WamiLoading(label: 'Recherche d’un coursier…');
          final delivered = tr.status == DeliveryStatus.delivered;
          return Stack(
            children: [
              Positioned(left: 0, right: 0, top: 0, height: 460, child: RouteMapView(progress: tr.progress)),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: StatusPill(
                    live: !delivered,
                    child: Text(
                      delivered
                          ? 'Colis livré'
                          : '${tr.status.label} · arrivée ${tr.eta == null ? '' : Fmt.hhmm(tr.eta!)}',
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: WamiSheet(
                  children: [
                    _Timeline(current: tr.status),
                    const Divider(),
                    if (!delivered) ...[
                      Row(
                        children: [
                          WamiAvatar(initials: Fmt.initials(tr.courier.name)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tr.courier.name, style: Theme.of(context).textTheme.titleSmall),
                                Text(
                                  '${tr.courier.vehicle} · ${tr.courier.plate}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          WamiIconButton(
                            icon: Icons.chat_bubble_outline_rounded,
                            tooltip: 'Écrire au coursier',
                            onPressed: () {},
                          ),
                          const SizedBox(width: 8),
                          GlowOrbButton(icon: Icons.call_rounded, tooltip: 'Appeler le coursier', onPressed: () {}),
                        ],
                      ),
                      if (tr.handoverCode.isNotEmpty)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SectionLabel('Code de remise'),
                                  Text(
                                    'Envoyé au ${state.draft.contactRole.toLowerCase()}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            for (final c in tr.handoverCode.split('')) ...[
                              Container(
                                width: 40,
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: context.wami.glass,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: WamiColors.orangeLight.withValues(alpha: 0.55)),
                                ),
                                child: NumberText(c, size: 18),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      WamiGhostButton(label: 'Partager le suivi', icon: Icons.ios_share_rounded, onPressed: () {}),
                    ] else
                      WamiSuccessView(
                        positive: true,
                        icon: Icons.check_rounded,
                        title: 'Colis remis',
                        message: 'Code de remise validé${tr.eta == null ? '' : ' · ${Fmt.hhmm(DateTime.now())}'}',
                        children: [
                          WamiPrimaryButton(label: 'Retour à l’accueil', onPressed: () => context.go(Routes.home)),
                        ],
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

class _Timeline extends StatelessWidget {
  const _Timeline({required this.current});
  final DeliveryStatus current;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final s in DeliveryStatus.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: WamiMotion.slow,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: s.index < current.index || current == DeliveryStatus.delivered
                        ? WamiColors.success
                        : (s == current ? WamiColors.orangeLight : context.wami.ink.withValues(alpha: 0.12)),
                    boxShadow: s == current && current != DeliveryStatus.delivered
                        ? [BoxShadow(color: WamiColors.orange.withValues(alpha: 0.6), blurRadius: 14)]
                        : null,
                  ),
                  child: s.index < current.index || current == DeliveryStatus.delivered
                      ? const Icon(Icons.check_rounded, size: 13, color: Color(0xFF0A1A12))
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  s.label,
                  style: s == current
                      ? t.titleSmall
                      : t.bodyMedium?.copyWith(
                          fontSize: 13.5,
                          color: s.index > current.index ? context.wami.inkMuted : null,
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

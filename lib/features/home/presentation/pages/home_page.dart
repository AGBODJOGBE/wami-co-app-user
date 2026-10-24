import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/wami_palette.dart';
import '../../../../core/theme/wami_tokens.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_background.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../domain/entities/home_feed.dart';
import '../cubit/home_cubit.dart';
import '../widgets/promo_carousel.dart';
import '../widgets/service_grid.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<HomeCubit>()..load(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return WamiBackground(
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            return switch (state.status) {
              HomeStatus.loading => const WamiLoading(),
              HomeStatus.failure => WamiErrorView(
                  failure: state.failure!,
                  onRetry: () => context.read<HomeCubit>().load(),
                ),
              HomeStatus.ready => _HomeContent(feed: state.feed!),
            };
          },
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.feed});
  final HomeFeed feed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.wami;
    return RefreshIndicator(
      onRefresh: () => context.read<HomeCubit>().load(),
      child: ListView(
        // Espace pour la barre de navigation flottante.
        padding: const EdgeInsets.only(top: 12, bottom: 110),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WamiSpace.screen),
            child: Row(
              children: [
                const WamiLogo(height: 24),
                const Spacer(),
                WamiIconButton(icon: Icons.notifications_none_rounded, tooltip: 'Notifications', onPressed: () {}),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WamiSpace.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bonjour ${feed.firstName}', style: t.bodySmall),
                Text('On va où aujourd’hui ?', style: t.headlineSmall),
                const SizedBox(height: 14),
                GlassCard(
                  onTap: () => context.push(Routes.ride),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: p.inkMuted),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Où allez-vous ?', style: t.bodyMedium?.copyWith(color: p.inkMuted))),
                      Icon(Icons.mic_none_rounded, color: p.orangeStrong),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: WamiSpace.screen),
              itemCount: feed.quickDestinations.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final q = feed.quickDestinations[i];
                return ActionChip(
                  avatar: Icon(_quickIcon(q.kind), size: 16, color: p.orangeStrong),
                  label: Text(q.label),
                  // On ne transmet qu'un libellé : une feature n'importe jamais les entités d'une autre.
                  onPressed: () => context.push(Routes.ride, extra: q.label),
                  backgroundColor: p.glass,
                  side: BorderSide(color: p.glassBorder),
                  shape: const StadiumBorder(),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          PromoCarousel(
            promos: feed.promos,
            onOpen: (promo) => context.push(Routes.forService(promo.service)),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WamiSpace.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionLabel('Nos services'),
                const SizedBox(height: 10),
                ServiceGrid(onOpen: (s) => context.push(Routes.forService(s))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _quickIcon(QuickDestinationKind k) => switch (k) {
        QuickDestinationKind.home => Icons.home_rounded,
        QuickDestinationKind.work => Icons.work_rounded,
        QuickDestinationKind.recent => Icons.history_rounded,
      };
}

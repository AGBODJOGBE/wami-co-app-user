import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/wami_palette.dart';
import '../../../../core/theme/wami_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_background.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../cubit/profile_cubit.dart';

/// Onglet Compte : profil, paramètres, assistance, confidentialité.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return WamiBackground(
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            final p = state.profile;
            if (p == null) return const WamiLoading();
            return ListView(
              padding: const EdgeInsets.fromLTRB(WamiSpace.screen, 12, WamiSpace.screen, 110),
              children: [
                Text('Compte', style: t.headlineSmall),
                const SizedBox(height: 14),
                GlassCard(
                  onTap: () => context.push(Routes.accountProfile),
                  child: Row(
                    children: [
                      WamiAvatar(initials: Fmt.initials(p.fullName), size: 56),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.fullName, style: t.titleMedium),
                            Text(p.phone, style: t.bodySmall),
                            const SizedBox(height: 4),
                            Row(children: [WamiTag(p.tier), const SizedBox(width: 6), RatingText(p.rating, size: 11)]),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: context.wami.inkMuted),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const GlassGroup(
                  children: [
                    _MenuItem(icon: Icons.person_outline_rounded, label: 'Mon profil', route: Routes.accountProfile),
                    _MenuItem(icon: Icons.settings_outlined, label: 'Paramètres', route: Routes.accountSettings),
                    _MenuItem(icon: Icons.support_agent_rounded, label: 'Assistance', route: Routes.accountSupport),
                    _MenuItem(icon: Icons.shield_outlined, label: 'Confidentialité', route: Routes.accountPrivacy),
                  ],
                ),
                const SizedBox(height: 14),
                GlassGroup(
                  children: [
                    ListTile(
                      leading: const IconBadge(Icons.card_giftcard_rounded),
                      title: Text('Parrainer un proche', style: t.titleSmall),
                      subtitle: Text('Récompense : [à valider]', style: t.bodySmall),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {},
                    ),
                    ListTile(
                      leading: IconBadge(Icons.logout_rounded, color: context.wami.danger),
                      title: Text('Se déconnecter', style: t.titleSmall?.copyWith(color: context.wami.danger)),
                      onTap: () => showWamiMessage(context, 'Déconnexion : flux d’authentification à brancher'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('WAMI · version 0.1.0', textAlign: TextAlign.center, style: t.bodySmall?.copyWith(fontSize: 11)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, required this.route});
  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconBadge(icon),
      title: Text(label, style: Theme.of(context).textTheme.titleSmall),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push(route),
    );
  }
}

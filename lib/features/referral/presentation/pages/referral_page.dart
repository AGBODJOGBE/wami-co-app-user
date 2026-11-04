import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/wami_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/load_status.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../../../core/widgets/wami_text_field.dart';
import '../../domain/entities/referral.dart';
import '../cubit/referral_cubit.dart';

/// Parrainer un proche : son code, ses filleuls, et le code d'un proche à utiliser.
class ReferralPage extends StatelessWidget {
  const ReferralPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => sl<ReferralCubit>()..load(), child: const _ReferralView());
  }
}

class _ReferralView extends StatefulWidget {
  const _ReferralView();

  @override
  State<_ReferralView> createState() => _ReferralViewState();
}

class _ReferralViewState extends State<_ReferralView> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReferralCubit, ReferralState>(
      listenWhen: (a, b) => b.failure != null && a.failure != b.failure || a.applied != b.applied && b.applied != null,
      listener: (context, state) {
        if (state.failure != null) {
          showWamiMessage(context, state.failure!.message);
        } else if (state.applied != null) {
          _code.clear();
          showWamiMessage(
            context,
            state.applied!.reward > 0
                ? 'Code appliqué : ${Fmt.fcfa(state.applied!.reward)} après votre première course.'
                : 'Code appliqué.',
          );
        }
      },
      builder: (context, state) {
        final o = state.overview;
        return WamiScreen(
          title: 'Parrainer un proche',
          subtitle: 'Invitez vos proches avec votre code.',
          body: o == null
              ? (state.status == LoadStatus.failure
                  ? WamiErrorView(failure: state.failure!, onRetry: () => context.read<ReferralCubit>().load())
                  : const SizedBox(height: 240, child: WamiLoading()))
              : Gap(
                  children: [
                    _CodeCard(overview: o),
                    _Stats(overview: o),
                    if (o.referrals.isNotEmpty) ...[
                      const SectionLabel('Vos filleuls'),
                      GlassGroup(children: [for (final r in o.referrals) _ReferralTile(referral: r)]),
                    ],
                    const SectionLabel('Vous avez un code ?'),
                    if (o.incoming != null)
                      GlassCard(
                        child: Text(
                          'Parrainage en cours avec le code ${o.incoming!.code}. '
                          '${o.incoming!.reward > 0 ? '${Fmt.fcfa(o.incoming!.reward)} vous seront offerts après votre première course.' : ''}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else ...[
                      WamiTextField(
                        hint: 'Code de votre proche',
                        label: 'Code de parrainage',
                        icon: Icons.card_giftcard_rounded,
                        controller: _code,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]'))],
                        onSubmitted: (v) => context.read<ReferralCubit>().apply(v),
                      ),
                      WamiPrimaryButton(
                        label: 'Utiliser ce code',
                        loading: state.applyStatus == LoadStatus.loading,
                        onPressed: () => context.read<ReferralCubit>().apply(_code.text),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.overview});
  final ReferralOverview overview;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final reward = overview.rewardPerReferral;
    return GlassCard(
      child: Column(
        children: [
          const SectionLabel('Votre code'),
          const SizedBox(height: 6),
          SelectableText(overview.code.isEmpty ? '—' : overview.code, style: t.headlineSmall),
          const SizedBox(height: 6),
          Text(
            reward == null
                ? 'Récompense par filleul : [à valider]'
                : 'Vous gagnez ${Fmt.fcfa(reward)} pour chaque proche qui fait sa première course.',
            textAlign: TextAlign.center,
            style: t.bodySmall,
          ),
          const SizedBox(height: 12),
          WamiGhostButton(
            label: 'Copier mon code',
            icon: Icons.copy_rounded,
            onPressed: overview.code.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: overview.code));
                    if (context.mounted) showWamiMessage(context, 'Code copié.');
                  },
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.overview});
  final ReferralOverview overview;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, int value) => Expanded(
          child: GlassCard(
            child: Column(
              children: [
                NumberText('$value', size: 20),
                const SizedBox(height: 2),
                Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
              ],
            ),
          ),
        );
    return Row(
      children: [
        cell('Invités', overview.total),
        const SizedBox(width: 8),
        cell('En attente', overview.pendingCount),
        const SizedBox(width: 8),
        cell('Validés', overview.validatedCount),
      ],
    );
  }
}

class _ReferralTile extends StatelessWidget {
  const _ReferralTile({required this.referral});
  final Referral referral;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final validated = referral.status == ReferralStatus.validated;
    return ListTile(
      leading: WamiAvatar(initials: Fmt.initials(referral.name)),
      title: Text(referral.name, style: t.titleSmall),
      subtitle: Text(Fmt.dayMonth(referral.validatedAt ?? referral.createdAt), style: t.bodySmall),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          WamiTag(referral.status.label, tint: validated ? WamiColors.success : null),
          if (validated && referral.reward > 0) Text('+${Fmt.fcfa(referral.reward)}', style: t.bodySmall),
        ],
      ),
    );
  }
}

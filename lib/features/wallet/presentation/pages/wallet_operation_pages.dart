import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/wami_colors.dart';
import '../../../../core/theme/wami_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/load_status.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../../../core/widgets/wami_selectors.dart';
import '../../../../core/widgets/wami_text_field.dart';
import '../../domain/entities/wallet.dart';
import '../bloc/wallet_bloc.dart';

const _topUpAmounts = [2000, 5000, 10000, 20000];
const _transferAmounts = [1000, 2000, 5000, 10000];

/// Montant central, en grand.
class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({required this.amount, required this.caption});
  final int amount;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SectionLabel('Montant'),
        const SizedBox(height: 4),
        Text(
          Fmt.fcfa(amount),
          style: WamiTypography.number(40).copyWith(
            shadows: [Shadow(color: WamiColors.orange.withValues(alpha: 0.45), blurRadius: 30)],
          ),
        ),
        Text(caption, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

Widget _amountChips(List<int> values, int current, ValueChanged<int> onPick) => Row(
      children: [
        for (final v in values) ...[
          WamiChip(label: Fmt.fcfa(v, withUnit: false), selected: v == current, expand: true, onTap: () => onPick(v)),
          if (v != values.last) const SizedBox(width: 8),
        ],
      ],
    );

/// Recharge depuis Mobile Money ou carte.
class TopUpPage extends StatefulWidget {
  const TopUpPage({super.key});

  @override
  State<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends State<TopUpPage> {
  int _amount = 5000;
  String? _sourceId;

  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(const WalletFormDataRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WalletBloc, WalletState>(
      listenWhen: (a, b) => a.operationStatus != b.operationStatus,
      listener: (context, state) {
        if (state.operationStatus == LoadStatus.ready) context.pushReplacement(Routes.walletSuccess);
        if (state.operationStatus == LoadStatus.failure) showWamiMessage(context, state.failure!.message);
      },
      builder: (context, state) {
        final sourceId = _sourceId ?? (state.sources.isEmpty ? null : state.sources.first.id);
        return WamiScreen(
          title: 'Recharger',
          body: Gap(
            children: [
              _AmountDisplay(amount: _amount, caption: 'Nouveau solde : ${Fmt.fcfa(state.balance + _amount)}'),
              _amountChips(_topUpAmounts, _amount, (v) => setState(() => _amount = v)),
              const SectionLabel('Depuis'),
              if (state.sources.isEmpty) const SizedBox(height: 100, child: WamiLoading()),
              for (final s in state.sources)
                WamiOptionTile(
                  title: s.kind == TopUpKind.card ? 'Carte bancaire' : 'Mobile Money',
                  subtitle: '${s.label} · ${s.masked}',
                  selected: s.id == sourceId,
                  onTap: () => setState(() => _sourceId = s.id),
                  leading:
                      IconBadge(s.kind == TopUpKind.card ? Icons.credit_card_rounded : Icons.phone_android_rounded),
                ),
              Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Frais de recharge : [à valider]',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ],
          ),
          bottom: WamiPrimaryButton(
            label: 'Recharger · ${Fmt.fcfa(_amount)}',
            loading: state.operationStatus == LoadStatus.loading,
            onPressed: sourceId == null
                ? null
                : () => context.read<WalletBloc>().add(WalletTopUpRequested(amount: _amount, sourceId: sourceId)),
          ),
        );
      },
    );
  }
}

/// Brouillon de transfert transmis à l'écran de vérification.
class TransferDraft {
  const TransferDraft({required this.beneficiary, required this.amount, this.note});
  final Beneficiary beneficiary;
  final int amount;
  final String? note;
}

class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  int _amount = 2000;
  String? _beneficiaryId;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(const WalletFormDataRequested());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WalletBloc>().state;
    final people = state.beneficiaries;
    final selected = people.where((b) => b.id == (_beneficiaryId ?? people.firstOrNull?.id)).firstOrNull;
    final enough = _amount <= state.balance;
    return WamiScreen(
      title: 'Transférer',
      body: Gap(
        children: [
          const SectionLabel('À qui ?'),
          SizedBox(
            height: 84,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _Person(
                  label: 'Nouveau',
                  initials: '+',
                  selected: false,
                  onTap: () => showWamiMessage(context, 'Ajout d’un contact : à brancher'),
                ),
                for (final b in people)
                  _Person(
                    label: b.name,
                    initials: Fmt.initials(b.name.replaceAll(RegExp(r'[\[\]]'), '')),
                    selected: b.id == selected?.id,
                    onTap: () => setState(() => _beneficiaryId = b.id),
                  ),
              ],
            ),
          ),
          _AmountDisplay(amount: _amount, caption: 'Solde après : ${Fmt.fcfa(state.balance - _amount)}'),
          _amountChips(_transferAmounts, _amount, (v) => setState(() => _amount = v)),
          WamiTextField(hint: 'Motif (facultatif)', controller: _note),
        ],
      ),
      bottom: WamiPrimaryButton(
        label: enough ? 'Continuer' : 'Solde insuffisant — rechargez',
        onPressed: selected == null
            ? null
            : () => enough
                ? context.push(
                    Routes.walletTransferReview,
                    extra: TransferDraft(beneficiary: selected, amount: _amount, note: _note.text),
                  )
                : context.pushReplacement(Routes.walletTopUp),
      ),
    );
  }
}

class _Person extends StatelessWidget {
  const _Person({required this.label, required this.initials, required this.selected, required this.onTap});
  final String label;
  final String initials;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 70,
          child: Column(
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: selected ? 1 : 0.75,
                child: Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [WamiColors.nuitLight, WamiColors.nuit]),
                    boxShadow: selected
                        ? [
                            const BoxShadow(color: WamiColors.night, spreadRadius: 2),
                            const BoxShadow(color: WamiColors.orangeLight, spreadRadius: 4),
                            BoxShadow(color: WamiColors.orange.withValues(alpha: 0.6), blurRadius: 18),
                          ]
                        : null,
                  ),
                  child: Text(
                    initials,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class TransferReviewPage extends StatelessWidget {
  const TransferReviewPage({super.key, required this.draft});
  final TransferDraft draft;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return BlocConsumer<WalletBloc, WalletState>(
      listenWhen: (a, b) => a.operationStatus != b.operationStatus,
      listener: (context, state) {
        if (state.operationStatus == LoadStatus.ready) context.pushReplacement(Routes.walletSuccess);
        if (state.operationStatus == LoadStatus.failure) showWamiMessage(context, state.failure!.message);
      },
      builder: (context, state) {
        final b = draft.beneficiary;
        return WamiScreen(
          title: 'Vérifier',
          body: Gap(
            children: [
              const SizedBox(height: 8),
              Center(child: WamiAvatar(initials: Fmt.initials(b.name.replaceAll(RegExp(r'[\[\]]'), '')), size: 72)),
              Center(child: Text(b.name, style: t.titleMedium)),
              Center(child: Text('${b.phone} · Compte WAMI', style: t.bodySmall)),
              GlassCard(
                child: Column(
                  children: [
                    _row(context, 'Montant', Fmt.fcfa(draft.amount)),
                    _row(context, 'Frais', '[à valider]'),
                    _row(context, 'Arrivée', 'Instantanée'),
                    if (draft.note?.isNotEmpty ?? false) _row(context, 'Motif', draft.note!),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Text('Total débité', style: t.titleSmall),
                        const Spacer(),
                        NumberText(Fmt.fcfa(draft.amount), size: 17),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.fingerprint_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Confirmation par code secret ou empreinte', style: t.bodySmall?.copyWith(fontSize: 11.5)),
                ],
              ),
            ],
          ),
          bottom: WamiPrimaryButton(
            label: 'Envoyer ${Fmt.fcfa(draft.amount)}',
            loading: state.operationStatus == LoadStatus.loading,
            onPressed: () => context.read<WalletBloc>().add(
                  WalletTransferRequested(beneficiary: b, amount: draft.amount, note: draft.note),
                ),
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [Text(label, style: t.bodySmall), const Spacer(), Text(value, style: t.labelLarge)]),
    );
  }
}

class WalletSuccessPage extends StatelessWidget {
  const WalletSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WalletBloc>().state;
    final op = state.lastOperation;
    final transfer = op?.kind == WalletOperationKind.transfer;
    return WamiScreen(
      showBack: false,
      body: WamiSuccessView(
        positive: transfer,
        icon: Icons.check_rounded,
        title: transfer ? 'Transfert envoyé' : 'Recharge réussie',
        message: op == null
            ? ''
            : transfer
                ? '${op.counterpart} a reçu ${Fmt.fcfa(op.amount)}.'
                : '${Fmt.fcfa(op.amount)} ajoutés à votre portefeuille.',
        children: [
          GlassCard(
            child: Column(
              children: [
                const SectionLabel('Nouveau solde'),
                const SizedBox(height: 4),
                NumberText(Fmt.fcfa(state.balance), size: 26),
              ],
            ),
          ),
        ],
      ),
      bottom: WamiPrimaryButton(label: 'Retour au portefeuille', onPressed: () => context.go(Routes.wallet)),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/current_session.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/wami_colors.dart';
import '../../../../core/theme/wami_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/load_status.dart';
import '../../../../core/utils/phone.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../../../core/widgets/wami_selectors.dart';
import '../../../../core/widgets/wami_text_field.dart';
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

/// Recharge par Mobile Money : le client confirme le paiement sur son téléphone.
class TopUpPage extends StatefulWidget {
  const TopUpPage({super.key});

  @override
  State<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends State<TopUpPage> {
  int _amount = 5000;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    // Par défaut, le numéro du compte.
    final own = sl<CurrentSession>().value?.phone;
    _phone = TextEditingController(text: own == null ? '' : BeninPhone.display(own));
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
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
        final loading = state.operationStatus == LoadStatus.loading;
        return WamiScreen(
          title: 'Recharger',
          body: Gap(
            children: [
              _AmountDisplay(amount: _amount, caption: 'Nouveau solde : ${Fmt.fcfa(state.balance + _amount)}'),
              _amountChips(_topUpAmounts, _amount, (v) => setState(() => _amount = v)),
              const SectionLabel('Numéro Mobile Money'),
              WamiTextField(
                hint: '01 97 12 34 56',
                icon: Icons.phone_android_rounded,
                prefixText: '${BeninPhone.countryCode} ',
                controller: _phone,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {}),
              ),
              Row(
                children: [
                  Icon(loading ? Icons.hourglass_top_rounded : Icons.lock_outline_rounded, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      loading
                          ? 'Confirmez le paiement sur votre téléphone. Cela peut prendre une minute.'
                          : 'Une demande de confirmation sera envoyée à ce numéro. Frais de recharge : [à valider]',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          bottom: WamiPrimaryButton(
            label: 'Recharger · ${Fmt.fcfa(_amount)}',
            loading: loading,
            onPressed: BeninPhone.isValid(_phone.text)
                ? () => context.read<WalletBloc>().add(
                      WalletTopUpRequested(amount: _amount, phone: BeninPhone.toInternational(_phone.text)!),
                    )
                : null,
          ),
        );
      },
    );
  }
}

/// Brouillon de transfert transmis à l'écran de vérification.
class TransferDraft {
  const TransferDraft({required this.recipientPhone, required this.amount, this.note});

  /// Numéro du destinataire, au format international.
  final String recipientPhone;
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
  final _phone = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WalletBloc>().state;
    final recipient = BeninPhone.toInternational(_phone.text);
    final enough = _amount <= state.balance;
    return WamiScreen(
      title: 'Transférer',
      body: Gap(
        children: [
          const SectionLabel('À qui ?'),
          WamiTextField(
            hint: 'Numéro du destinataire',
            icon: Icons.person_search_rounded,
            prefixText: '${BeninPhone.countryCode} ',
            controller: _phone,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
          ),
          Text('Le destinataire doit avoir un compte WAMI.', style: Theme.of(context).textTheme.bodySmall),
          _AmountDisplay(amount: _amount, caption: 'Solde après : ${Fmt.fcfa(state.balance - _amount)}'),
          _amountChips(_transferAmounts, _amount, (v) => setState(() => _amount = v)),
          WamiTextField(hint: 'Motif (facultatif)', controller: _note),
        ],
      ),
      bottom: WamiPrimaryButton(
        label: enough ? 'Continuer' : 'Solde insuffisant — rechargez',
        onPressed: recipient == null
            ? null
            : () => enough
                ? context.push(
                    Routes.walletTransferReview,
                    extra: TransferDraft(recipientPhone: recipient, amount: _amount, note: _note.text),
                  )
                : context.pushReplacement(Routes.walletTopUp),
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
        return WamiScreen(
          title: 'Vérifier',
          body: Gap(
            children: [
              const SizedBox(height: 8),
              const Center(child: WamiAvatar(initials: '→', size: 72)),
              Center(child: Text(BeninPhone.display(draft.recipientPhone), style: t.titleMedium)),
              Center(child: Text('${BeninPhone.countryCode} · Compte WAMI', style: t.bodySmall)),
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
                  WalletTransferRequested(recipientPhone: draft.recipientPhone, amount: draft.amount, note: draft.note),
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

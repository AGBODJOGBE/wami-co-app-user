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

/// Recharge par Mobile Money : le client confirme le paiement sur son téléphone.
class TopUpPage extends StatefulWidget {
  const TopUpPage({super.key});

  @override
  State<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends State<TopUpPage> {
  int _amount = 5000;
  String? _sourceId;

  /// « Autre numéro » : le client saisit un numéro qui n'est pas enregistré.
  bool _other = false;
  final _phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(const WalletFormDataRequested());
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  /// Numéro à débiter, au format international, ou `null` s'il est incomplet.
  String? _resolvePhone(TopUpSource? source) {
    if (_other || source == null) return BeninPhone.toInternational(_phone.text);
    // Une carte n'a pas de numéro : le paiement passe par le numéro du compte.
    return source.phone ?? sl<CurrentSession>().value?.phone;
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
        final selected = state.sources.where((s) => s.id == (_sourceId ?? state.sources.firstOrNull?.id)).firstOrNull;
        final phone = _resolvePhone(selected);
        return WamiScreen(
          title: 'Recharger',
          body: Gap(
            children: [
              _AmountDisplay(amount: _amount, caption: 'Nouveau solde : ${Fmt.fcfa(state.balance + _amount)}'),
              _amountChips(_topUpAmounts, _amount, (v) => setState(() => _amount = v)),
              const SectionLabel('Depuis'),
              for (final s in state.sources)
                WamiOptionTile(
                  title: s.kind == TopUpKind.card ? 'Carte bancaire' : 'Mobile Money',
                  subtitle: '${s.label} · ${s.masked}',
                  selected: !_other && s.id == selected?.id,
                  onTap: () => setState(() {
                    _other = false;
                    _sourceId = s.id;
                  }),
                  leading:
                      IconBadge(s.kind == TopUpKind.card ? Icons.credit_card_rounded : Icons.phone_android_rounded),
                ),
              WamiOptionTile(
                title: 'Autre numéro Mobile Money',
                subtitle: 'Saisir un numéro',
                selected: _other,
                onTap: () => setState(() => _other = true),
                leading: const IconBadge(Icons.dialpad_rounded),
              ),
              if (_other)
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
                          : 'Une demande de confirmation sera envoyée au numéro choisi. Frais de recharge : [à valider]',
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
            onPressed: phone == null
                ? null
                : () => context.read<WalletBloc>().add(WalletTopUpRequested(amount: _amount, phone: phone)),
          ),
        );
      },
    );
  }
}

/// Brouillon de transfert transmis à l'écran de vérification.
class TransferDraft {
  const TransferDraft({required this.recipientPhone, required this.amount, this.recipientName, this.note});

  /// Numéro du destinataire, au format international.
  final String recipientPhone;

  /// Nom du contact, s'il est enregistré.
  final String? recipientName;
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

  /// « Nouveau » : le client saisit un numéro qui n'est pas dans ses contacts.
  bool _newNumber = false;
  final _phone = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(const WalletFormDataRequested());
  }

  @override
  void dispose() {
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WalletBloc>().state;
    final people = state.beneficiaries;
    // Sans contact enregistré, on saisit directement un numéro.
    final typing = _newNumber || people.isEmpty;
    final selected = typing ? null : people.where((b) => b.id == (_beneficiaryId ?? people.first.id)).firstOrNull;
    final recipient = typing ? BeninPhone.toInternational(_phone.text) : selected?.phone;
    final enough = _amount <= state.balance;
    return WamiScreen(
      title: 'Transférer',
      body: Gap(
        children: [
          const SectionLabel('À qui ?'),
          if (people.isNotEmpty)
            SizedBox(
              height: 84,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _Person(
                    label: 'Nouveau',
                    initials: '+',
                    selected: _newNumber,
                    onTap: () => setState(() => _newNumber = true),
                  ),
                  for (final b in people)
                    _Person(
                      label: b.name,
                      initials: Fmt.initials(b.name.replaceAll(RegExp(r'[\[\]]'), '')),
                      selected: !_newNumber && b.id == selected?.id,
                      onTap: () => setState(() {
                        _newNumber = false;
                        _beneficiaryId = b.id;
                      }),
                    ),
                ],
              ),
            ),
          if (typing) ...[
            WamiTextField(
              hint: 'Numéro du destinataire',
              icon: Icons.person_search_rounded,
              prefixText: '${BeninPhone.countryCode} ',
              controller: _phone,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
            ),
            Text('Le destinataire doit avoir un compte WAMI.', style: Theme.of(context).textTheme.bodySmall),
          ],
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
                    extra: TransferDraft(
                      recipientPhone: recipient,
                      recipientName: selected?.name,
                      amount: _amount,
                      note: _note.text,
                    ),
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
        return WamiScreen(
          title: 'Vérifier',
          body: Gap(
            children: [
              const SizedBox(height: 8),
              Center(
                child: WamiAvatar(
                  initials: draft.recipientName == null
                      ? '→'
                      : Fmt.initials(draft.recipientName!.replaceAll(RegExp(r'[\[\]]'), '')),
                  size: 72,
                ),
              ),
              Center(
                child: Text(draft.recipientName ?? BeninPhone.display(draft.recipientPhone), style: t.titleMedium),
              ),
              Center(
                child: Text(
                  '${BeninPhone.countryCode} ${BeninPhone.display(draft.recipientPhone)} · Compte WAMI',
                  style: t.bodySmall,
                ),
              ),
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

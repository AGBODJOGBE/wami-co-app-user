import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_live.dart';
import '../../../../core/widgets/wami_text_field.dart';
import '../bloc/ride_bloc.dart';

/// Choix d'une nouvelle destination pendant la course : le chauffeur doit l'accepter.
Future<void> showDestinationChangeSheet(BuildContext context) {
  final bloc = context.read<RideBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(value: bloc, child: const _DestinationChangeSheet()),
  );
}

class _DestinationChangeSheet extends StatefulWidget {
  const _DestinationChangeSheet();

  @override
  State<_DestinationChangeSheet> createState() => _DestinationChangeSheetState();
}

class _DestinationChangeSheetState extends State<_DestinationChangeSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RideBloc>().state;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: WamiSheet(
        children: [
          Text('Changer la destination', style: t.titleMedium),
          Text('Le chauffeur reçoit votre demande et peut l’accepter ou la refuser.', style: t.bodySmall),
          WamiTextField(
            hint: 'Nouvelle destination',
            label: 'Destination',
            icon: Icons.place_outlined,
            controller: _query,
            autofocus: true,
            onChanged: (q) => context.read<RideBloc>().add(RideQueryChanged(q)),
          ),
          if (state.query.length >= 2 && state.suggestions.isEmpty)
            Text('Aucun lieu trouvé pour « ${state.query} ».', style: t.bodySmall),
          for (final place in state.suggestions.take(5))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const IconBadge(Icons.place_rounded),
              title: Text(place.name, style: t.titleSmall),
              subtitle: Text(place.address, style: t.bodySmall),
              onTap: () {
                context.read<RideBloc>().add(RideDestinationChangeRequested(place));
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}

/// Part du portefeuille pour la course en cours ; le reste se règle en espèces.
Future<void> showPaymentSplitSheet(BuildContext context) {
  final bloc = context.read<RideBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(value: bloc, child: const _PaymentSplitSheet()),
  );
}

class _PaymentSplitSheet extends StatefulWidget {
  const _PaymentSplitSheet();

  @override
  State<_PaymentSplitSheet> createState() => _PaymentSplitSheetState();
}

class _PaymentSplitSheetState extends State<_PaymentSplitSheet> {
  late final _amount = TextEditingController(
    text: context.read<RideBloc>().state.paymentSplit?.walletAmount?.toString() ?? '',
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final value = int.tryParse(_amount.text.trim());
    context.read<RideBloc>().add(RidePaymentSplitSet(value));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final split = context.watch<RideBloc>().state.paymentSplit;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: WamiSheet(
        children: [
          Text('Répartition du paiement', style: t.titleMedium),
          Text(
            'Indiquez ce que vous payez avec votre portefeuille : le reste se règle en espèces. '
            'Sans montant, le maximum du portefeuille est utilisé.',
            style: t.bodySmall,
          ),
          WamiTextField(
            hint: 'Montant en FCFA (vide = automatique)',
            label: 'Part du portefeuille',
            icon: Icons.account_balance_wallet_outlined,
            controller: _amount,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _save(),
          ),
          if (split != null)
            Text(
              split.isAutomatic
                  ? 'Mode automatique'
                  : 'Enregistré : ${Fmt.fcfa(split.walletAmount!)} · espèces estimées ${Fmt.fcfa(split.cashAmount)}',
              style: t.bodySmall,
            ),
          WamiPrimaryButton(label: 'Enregistrer', onPressed: _save),
        ],
      ),
    );
  }
}

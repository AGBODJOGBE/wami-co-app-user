import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/load_status.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_live.dart';
import '../../../../core/widgets/wami_selectors.dart';
import '../../../../core/widgets/wami_text_field.dart';
import '../../domain/entities/user_profile.dart';
import '../cubit/profile_cubit.dart';

/// Contacts à vérifier : l'e-mail (une fois renseigné) et le téléphone.
class VerificationBanners extends StatelessWidget {
  const VerificationBanners({super.key, required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final pending = [
      if (!profile.phoneVerified) VerificationKind.phone,
      if (!profile.emailVerified && profile.email.isNotEmpty) VerificationKind.email,
    ];
    if (pending.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final kind in pending)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              child: Row(
                children: [
                  IconBadge(kind == VerificationKind.email ? Icons.mark_email_unread_outlined : Icons.sms_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kind == VerificationKind.email ? 'E-mail non vérifié' : 'Téléphone non vérifié',
                          style: t.titleSmall,
                        ),
                        Text('Saisissez le code reçu', style: t.bodySmall),
                      ],
                    ),
                  ),
                  TextButton(onPressed: () => showVerifySheet(context, kind), child: const Text('Vérifier')),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> showVerifySheet(BuildContext context, VerificationKind kind) {
  final cubit = context.read<ProfileCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(value: cubit, child: _VerifySheet(kind: kind)),
  );
}

class _VerifySheet extends StatefulWidget {
  const _VerifySheet({required this.kind});
  final VerificationKind kind;

  @override
  State<_VerifySheet> createState() => _VerifySheetState();
}

class _VerifySheetState extends State<_VerifySheet> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final email = widget.kind == VerificationKind.email;
    return BlocConsumer<ProfileCubit, ProfileState>(
      listenWhen: (a, b) => a.verifyStatus != b.verifyStatus,
      listener: (context, state) {
        if (state.verifyStatus == LoadStatus.ready) Navigator.of(context).pop();
      },
      builder: (context, state) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: WamiSheet(
            children: [
              Text(email ? 'Vérifier mon e-mail' : 'Vérifier mon téléphone', style: t.titleMedium),
              Text(
                email
                    ? 'Entrez le code à 6 chiffres envoyé par e-mail.'
                    : 'Entrez le code à 6 chiffres envoyé par SMS.',
                style: t.bodySmall,
              ),
              WamiTextField(
                hint: '123456',
                label: 'Code',
                icon: Icons.pin_outlined,
                controller: _code,
                autofocus: true,
                maxLength: 6,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              TextButton(
                onPressed: () => context.read<ProfileCubit>().resendCodes(),
                child: const Text('Renvoyer les codes'),
              ),
              WamiPrimaryButton(
                label: 'Vérifier',
                loading: state.verifyStatus == LoadStatus.loading,
                onPressed: () => context.read<ProfileCubit>().verify(widget.kind, _code.text),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Civilité (femme / homme).
class GenderPicker extends StatelessWidget {
  const GenderPicker({super.key, required this.gender});
  final Gender? gender;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final g in Gender.values) ...[
          WamiChip(
            label: g.label,
            selected: gender == g,
            onTap: () => context.read<ProfileCubit>().setGender(g),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

/// Adresse de résidence : résumé et modification.
class AddressCard extends StatelessWidget {
  const AddressCard({super.key, required this.address});
  final PostalAddress? address;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassCard(
      onTap: () => showAddressSheet(context, address),
      child: Row(
        children: [
          const IconBadge(Icons.home_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(address?.summary ?? 'Ajouter mon adresse', style: t.titleSmall),
                Text(
                  address?.landmark == null ? 'Ville et quartier obligatoires' : 'Repère : ${address!.landmark}',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

Future<void> showAddressSheet(BuildContext context, PostalAddress? current) {
  final cubit = context.read<ProfileCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(value: cubit, child: _AddressSheet(current: current)),
  );
}

class _AddressSheet extends StatefulWidget {
  const _AddressSheet({this.current});
  final PostalAddress? current;

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  late final _city = TextEditingController(text: widget.current?.city);
  late final _quarter = TextEditingController(text: widget.current?.quarter);
  late final _street = TextEditingController(text: widget.current?.street);
  late final _landmark = TextEditingController(text: widget.current?.landmark);

  @override
  void dispose() {
    for (final c in [_city, _quarter, _street, _landmark]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: WamiSheet(
        children: [
          Text('Mon adresse', style: Theme.of(context).textTheme.titleMedium),
          WamiTextField(hint: 'Cotonou', label: 'Ville', icon: Icons.location_city_outlined, controller: _city),
          WamiTextField(hint: 'Akpakpa', label: 'Quartier', icon: Icons.map_outlined, controller: _quarter),
          WamiTextField(
            hint: 'Avenue Steinmetz',
            label: 'Rue (facultatif)',
            icon: Icons.signpost_outlined,
            controller: _street,
          ),
          WamiTextField(
            hint: 'Près du marché',
            label: 'Repère (facultatif)',
            icon: Icons.flag_outlined,
            controller: _landmark,
          ),
          WamiPrimaryButton(
            label: 'Enregistrer',
            onPressed: () {
              context.read<ProfileCubit>().setAddress(
                    PostalAddress(
                      city: _city.text,
                      quarter: _quarter.text,
                      street: _street.text,
                      landmark: _landmark.text,
                    ),
                  );
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

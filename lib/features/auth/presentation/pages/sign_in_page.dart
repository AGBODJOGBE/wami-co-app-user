import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/load_status.dart';
import '../../../../core/utils/phone.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../../../core/widgets/wami_selectors.dart';
import '../../../../core/widgets/wami_text_field.dart';
import '../../domain/entities/auth_entities.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/sign_in_cubit.dart';

/// Connexion et inscription : une seule route, quatre étapes (voir [SignInStep]).
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SignInCubit, SignInState>(
      listenWhen: (a, b) => a.status != b.status || a.session != b.session,
      listener: (context, state) {
        final session = state.session;
        if (session != null) {
          // Le routeur réagit au changement d'état d'AuthCubit et ouvre l'accueil.
          context.read<AuthCubit>().signedIn(session);
        } else if (state.status == LoadStatus.failure) {
          showWamiMessage(context, state.failure!.message);
        }
      },
      builder: (context, state) {
        final cubit = context.read<SignInCubit>();
        return WamiScreen(
          showBack: state.step != SignInStep.phone,
          onBack: cubit.changePhone,
          title: switch (state.step) {
            SignInStep.phone => 'Bienvenue',
            SignInStep.code => 'Code de vérification',
            SignInStep.password => 'Bon retour',
            SignInStep.register => 'Créer votre compte',
          },
          subtitle: switch (state.step) {
            SignInStep.phone => 'Entrez votre numéro pour vous connecter ou créer un compte.',
            SignInStep.code => 'Code envoyé par SMS au ${BeninPhone.display(state.phone)}.',
            SignInStep.password => 'Saisissez votre mot de passe pour ${BeninPhone.display(state.phone)}.',
            SignInStep.register => 'Quelques informations pour finir l’inscription.',
          },
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey(state.step),
              child: switch (state.step) {
                SignInStep.phone => _PhoneStep(state: state),
                SignInStep.code => _CodeStep(state: state),
                SignInStep.password => _PasswordStep(state: state),
                SignInStep.register => _RegisterStep(state: state),
              },
            ),
          ),
        );
      },
    );
  }
}

class _PhoneStep extends StatefulWidget {
  const _PhoneStep({required this.state});
  final SignInState state;

  @override
  State<_PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends State<_PhoneStep> {
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _submit() => context.read<SignInCubit>().submitPhone(_phone.text);

  @override
  Widget build(BuildContext context) {
    return Gap(
      children: [
        const Center(child: WamiLogo(height: 34)),
        const SizedBox(height: 8),
        WamiTextField(
          hint: '01 97 12 34 56',
          label: 'Numéro de téléphone',
          icon: Icons.phone_android_rounded,
          prefixText: '${BeninPhone.countryCode} ',
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofocus: true,
          maxLength: 16,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
          onSubmitted: (_) => _submit(),
        ),
        WamiPrimaryButton(label: 'Recevoir le code', loading: widget.state.busy, onPressed: _submit),
        Text(
          'En continuant, vous acceptez les conditions d’utilisation et la politique de confidentialité.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _CodeStep extends StatefulWidget {
  const _CodeStep({required this.state});
  final SignInState state;

  @override
  State<_CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends State<_CodeStep> {
  final _code = TextEditingController();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  int get _secondsLeft {
    final at = widget.state.resendAvailableAt;
    if (at == null) return 0;
    final left = at.difference(DateTime.now()).inSeconds + 1;
    return left < 0 ? 0 : left;
  }

  void _submit() => context.read<SignInCubit>().submitCode(_code.text);

  @override
  Widget build(BuildContext context) {
    final wait = _secondsLeft;
    return Gap(
      children: [
        WamiTextField(
          hint: '••••••',
          label: 'Code à 6 chiffres',
          icon: Icons.sms_outlined,
          controller: _code,
          keyboardType: TextInputType.number,
          autofocus: true,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) {
            if (v.length == 6) _submit();
          },
          onSubmitted: (_) => _submit(),
        ),
        WamiPrimaryButton(label: 'Vérifier', loading: widget.state.busy, onPressed: _submit),
        WamiGhostButton(
          label: wait > 0 ? 'Renvoyer le code (${wait}s)' : 'Renvoyer le code',
          onPressed: wait > 0 || widget.state.busy ? null : () => context.read<SignInCubit>().resendCode(),
        ),
        WamiGhostButton(label: 'Ce n’est pas mon numéro', onPressed: () => context.read<SignInCubit>().changePhone()),
      ],
    );
  }
}

class _PasswordStep extends StatefulWidget {
  const _PasswordStep({required this.state});
  final SignInState state;

  @override
  State<_PasswordStep> createState() => _PasswordStepState();
}

class _PasswordStepState extends State<_PasswordStep> {
  final _password = TextEditingController();
  bool _hidden = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() => context.read<SignInCubit>().submitPassword(_password.text);

  @override
  Widget build(BuildContext context) {
    return Gap(
      children: [
        WamiTextField(
          hint: 'Mot de passe',
          label: 'Mot de passe',
          icon: Icons.lock_outline_rounded,
          controller: _password,
          obscureText: _hidden,
          autofocus: true,
          onSubmitted: (_) => _submit(),
          suffix: IconButton(
            tooltip: _hidden ? 'Afficher' : 'Masquer',
            icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
        ),
        WamiPrimaryButton(label: 'Se connecter', loading: widget.state.busy, onPressed: _submit),
      ],
    );
  }
}

class _RegisterStep extends StatefulWidget {
  const _RegisterStep({required this.state});
  final SignInState state;

  @override
  State<_RegisterStep> createState() => _RegisterStepState();
}

class _RegisterStepState extends State<_RegisterStep> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _referral = TextEditingController();
  Gender? _gender;
  bool _hidden = true;
  bool _submitted = false;

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _password, _referral]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _passwordError => _submitted ? PasswordPolicy.check(_password.text) : null;

  void _submit() {
    setState(() => _submitted = true);
    final gender = _gender;
    if (gender == null) {
      showWamiMessage(context, 'Choisissez votre genre.');
      return;
    }
    if (PasswordPolicy.check(_password.text) != null) return;
    context.read<SignInCubit>().submitRegistration(
          firstName: _firstName.text,
          lastName: _lastName.text,
          password: _password.text,
          gender: gender,
          email: _email.text,
          referralCode: _referral.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Gap(
      children: [
        WamiTextField(
          hint: 'Prénom',
          label: 'Prénom',
          icon: Icons.person_outline_rounded,
          controller: _firstName,
          autofocus: true,
          textInputAction: TextInputAction.next,
        ),
        WamiTextField(
          hint: 'Nom',
          label: 'Nom',
          icon: Icons.badge_outlined,
          controller: _lastName,
          textInputAction: TextInputAction.next,
        ),
        Row(
          children: [
            WamiChip(
              label: 'Homme',
              selected: _gender == Gender.male,
              expand: true,
              onTap: () => setState(() => _gender = Gender.male),
            ),
            const SizedBox(width: 8),
            WamiChip(
              label: 'Femme',
              selected: _gender == Gender.female,
              expand: true,
              onTap: () => setState(() => _gender = Gender.female),
            ),
          ],
        ),
        WamiTextField(
          hint: 'Adresse e-mail (facultatif)',
          label: 'E-mail',
          icon: Icons.mail_outline_rounded,
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        WamiTextField(
          hint: '8 caractères, majuscule, minuscule, chiffre',
          label: 'Mot de passe',
          icon: Icons.lock_outline_rounded,
          controller: _password,
          obscureText: _hidden,
          errorText: _passwordError,
          onChanged: (_) {
            if (_submitted) setState(() {});
          },
          suffix: IconButton(
            tooltip: _hidden ? 'Afficher' : 'Masquer',
            icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
        ),
        WamiTextField(
          hint: 'Code de parrainage (facultatif)',
          label: 'Parrainage',
          icon: Icons.card_giftcard_rounded,
          controller: _referral,
          onSubmitted: (_) => _submit(),
        ),
        WamiPrimaryButton(label: 'Créer mon compte', loading: widget.state.busy, onPressed: _submit),
      ],
    );
  }
}

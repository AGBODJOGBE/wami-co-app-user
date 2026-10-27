import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/service_type.dart';
import '../../../../core/theme/wami_colors.dart';
import '../../../../core/theme/wami_palette.dart';
import '../../../../core/theme/wami_tokens.dart';
import '../../../../core/theme/wami_typography.dart';
import '../../../../core/utils/load_status.dart';
import '../../../../core/utils/phone.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_background.dart';
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
///
/// Numéro (1/3) → code SMS (2/3) → mot de passe si le compte existe, sinon inscription (3/3).
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
        final phone = BeninPhone.display(state.phone);
        return _AuthLayout(
          step: state.step,
          onBack: context.read<SignInCubit>().changePhone,
          title: switch (state.step) {
            SignInStep.phone => 'Bienvenue',
            SignInStep.code => 'Code de vérification',
            SignInStep.password => 'Bon retour',
            SignInStep.register => 'Créer votre compte',
          },
          subtitle: switch (state.step) {
            SignInStep.phone => 'Entrez votre numéro pour vous connecter ou créer un compte. Un code vous sera envoyé '
                'par SMS.',
            SignInStep.code => 'Saisissez le code à 6 chiffres envoyé par SMS au $phone.',
            SignInStep.password => 'Saisissez votre mot de passe pour accéder à votre compte.',
            SignInStep.register => 'Votre numéro est vérifié. Encore quelques informations et c’est parti.',
          },
          child: switch (state.step) {
            SignInStep.phone => _PhoneStep(state: state),
            SignInStep.code => _CodeStep(state: state),
            SignInStep.password => _PasswordStep(state: state),
            SignInStep.register => _RegisterStep(state: state),
          },
        );
      },
    );
  }
}

/// Mise en page commune aux étapes : logo ou retour, progression, titre complet, contenu.
class _AuthLayout extends StatelessWidget {
  const _AuthLayout({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.child,
  });

  final SignInStep step;
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Widget child;

  int get _position => switch (step) {
        SignInStep.phone => 1,
        SignInStep.code => 2,
        SignInStep.password || SignInStep.register => 3,
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final first = step == SignInStep.phone;
    return Scaffold(
      backgroundColor: context.wami.surface,
      body: WamiBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(WamiSpace.screen, 12, WamiSpace.screen, WamiSpace.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      if (first)
                        const WamiLogo(height: 28)
                      else
                        WamiIconButton(icon: Icons.arrow_back_ios_new_rounded, tooltip: 'Retour', onPressed: onBack),
                      const Spacer(),
                      _StepProgress(position: _position),
                    ],
                  ),
                ),
                const SizedBox(height: WamiSpace.s6),
                if (first) ...[
                  const _ServicesBanner(),
                  const SizedBox(height: WamiSpace.s6),
                ],
                Text(title, style: t.displaySmall),
                const SizedBox(height: WamiSpace.s2),
                Text(subtitle, style: t.bodyMedium?.copyWith(color: context.wami.inkMuted)),
                const SizedBox(height: WamiSpace.s5),
                AnimatedSwitcher(
                  duration: WamiMotion.base,
                  switchInCurve: WamiMotion.curve,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(key: ValueKey(step), child: child),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// « Étape 2 sur 3 » et trois segments, le segment en cours en orange.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.position});
  final int position;

  @override
  Widget build(BuildContext context) {
    final p = context.wami;
    return Semantics(
      label: 'Étape $position sur 3',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$position/3', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.inkMuted)),
          const SizedBox(width: 10),
          for (var i = 1; i <= 3; i++) ...[
            if (i > 1) const SizedBox(width: 4),
            AnimatedContainer(
              duration: WamiMotion.base,
              width: i == position ? 22 : 10,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(WamiRadius.pill),
                gradient: i <= position ? WamiEffects.ctaGradient : null,
                color: i <= position ? null : p.glassBorder,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Les quatre univers WAMI, pour dire en un coup d'œil ce que le compte ouvre.
class _ServicesBanner extends StatelessWidget {
  const _ServicesBanner();

  static const _services = [
    (ServiceArt.moto, 'Courses', WamiColors.glowMobilite),
    (ServiceArt.colis, 'Livraison', WamiColors.glowLivraison),
    (ServiceArt.bus, 'Bus', WamiColors.glowBus),
    (ServiceArt.hotel, 'Séjours', WamiColors.glowHebergement),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          for (final (art, label, glow) in _services)
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [glow.withValues(alpha: 0.28), glow.withValues(alpha: 0)]),
                    ),
                    child: ServiceIllustration(art, size: 46),
                  ),
                  const SizedBox(height: 6),
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Numéro affiché avec un lien « Modifier » (retour à l'étape 1).
class _PhoneRecap extends StatelessWidget {
  const _PhoneRecap({required this.phone, this.verified = false});
  final String phone;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final p = context.wami;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      child: Row(
        children: [
          IconBadge(
            verified ? Icons.verified_rounded : Icons.phone_android_rounded,
            color: verified ? p.success : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(verified ? 'Numéro vérifié' : 'Votre numéro', style: Theme.of(context).textTheme.bodySmall),
                Text(BeninPhone.display(phone), style: WamiTypography.number(15, color: p.ink)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.read<SignInCubit>().changePhone(),
            child: Text('Modifier', style: TextStyle(color: p.orangeStrong, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
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
    final t = Theme.of(context).textTheme;
    final strong = TextStyle(fontWeight: FontWeight.w700, color: context.wami.ink);
    return Gap(
      gap: WamiSpace.s4,
      children: [
        WamiTextField(
          hint: '01 97 12 34 56',
          label: 'Numéro de téléphone',
          icon: Icons.phone_android_rounded,
          prefixText: '${BeninPhone.countryCode} ',
          controller: _phone,
          keyboardType: TextInputType.phone,
          maxLength: 16,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
          onSubmitted: (_) => _submit(),
        ),
        WamiPrimaryButton(
          label: 'Recevoir le code',
          icon: Icons.sms_outlined,
          loading: widget.state.busy,
          onPressed: _submit,
        ),
        Text.rich(
          TextSpan(
            text: 'En continuant, vous acceptez les ',
            children: [
              TextSpan(text: 'conditions d’utilisation', style: strong),
              const TextSpan(text: ' et la '),
              TextSpan(text: 'politique de confidentialité', style: strong),
              const TextSpan(text: ' de WAMI.'),
            ],
          ),
          textAlign: TextAlign.center,
          style: t.bodySmall,
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
    final p = context.wami;
    final wait = _secondsLeft;
    return Gap(
      gap: WamiSpace.s4,
      children: [
        _PhoneRecap(phone: widget.state.phone),
        _CodeBoxes(
          controller: _code,
          onCompleted: _submit,
        ),
        WamiPrimaryButton(label: 'Vérifier', loading: widget.state.busy, onPressed: _submit),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Pas reçu de code ?', style: Theme.of(context).textTheme.bodySmall),
            TextButton(
              onPressed: wait > 0 || widget.state.busy ? null : () => context.read<SignInCubit>().resendCode(),
              child: Text(
                wait > 0 ? 'Renvoyer dans ${wait}s' : 'Renvoyer le code',
                style: TextStyle(fontWeight: FontWeight.w700, color: wait > 0 ? p.inkMuted : p.orangeStrong),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Six cases pour le code SMS. Un seul champ invisible reçoit la saisie (clavier, collage,
/// remplissage automatique du SMS) ; les cases ne font que l'afficher.
class _CodeBoxes extends StatefulWidget {
  const _CodeBoxes({required this.controller, required this.onCompleted});
  final TextEditingController controller;
  final VoidCallback onCompleted;

  static const length = 6;

  @override
  State<_CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<_CodeBoxes> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.wami;
    final code = widget.controller.text;
    return Semantics(
      label: 'Code à 6 chiffres',
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < _CodeBoxes.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _box(p, i < code.length ? code[i] : '', active: _focus.hasFocus && i == code.length)),
              ],
            ],
          ),
          Positioned.fill(
            child: TextFormField(
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: _CodeBoxes.length,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              showCursor: false,
              enableInteractiveSelection: false,
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                counterText: '',
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) {
                setState(() {});
                if (v.length == _CodeBoxes.length) widget.onCompleted();
              },
              onFieldSubmitted: (_) => widget.onCompleted(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(WamiPalette p, String digit, {required bool active}) {
    final filled = digit.isNotEmpty;
    return AnimatedContainer(
      duration: WamiMotion.fast,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? WamiColors.orange.withValues(alpha: 0.10) : p.glass,
        borderRadius: BorderRadius.circular(WamiRadius.md),
        border: Border.all(
          color: active
              ? WamiColors.orangeLight
              : filled
                  ? WamiColors.orangeLight.withValues(alpha: 0.45)
                  : p.glassBorder,
          width: active ? 1.6 : 1,
        ),
        boxShadow: active ? WamiEffects.glow(WamiColors.orange, 0.35) : null,
      ),
      child: Text(digit, style: WamiTypography.number(22, color: p.ink)),
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
      gap: WamiSpace.s4,
      children: [
        _PhoneRecap(phone: widget.state.phone, verified: true),
        WamiTextField(
          hint: 'Votre mot de passe',
          label: 'Mot de passe',
          icon: Icons.lock_outline_rounded,
          controller: _password,
          obscureText: _hidden,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          suffix: _VisibilityToggle(hidden: _hidden, onToggle: () => setState(() => _hidden = !_hidden)),
        ),
        WamiPrimaryButton(
          label: 'Se connecter',
          icon: Icons.arrow_forward_rounded,
          loading: widget.state.busy,
          onPressed: _submit,
        ),
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

  void _submit() {
    setState(() => _submitted = true);
    final gender = _gender;
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      showWamiMessage(context, 'Indiquez votre prénom et votre nom.');
      return;
    }
    if (gender == null) {
      showWamiMessage(context, 'Choisissez votre genre.');
      return;
    }
    if (PasswordPolicy.check(_password.text) != null) {
      showWamiMessage(context, 'Le mot de passe ne respecte pas encore toutes les règles.');
      return;
    }
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
    final missingGender = _submitted && _gender == null;
    return Gap(
      gap: WamiSpace.s4,
      children: [
        _PhoneRecap(phone: widget.state.phone, verified: true),
        _FormSection(
          label: 'Vous',
          children: [
            WamiTextField(
              hint: 'Prénom',
              label: 'Prénom',
              icon: Icons.person_outline_rounded,
              controller: _firstName,
              autofocus: true,
              textInputAction: TextInputAction.next,
              errorText: _submitted && _firstName.text.trim().isEmpty ? 'Indiquez votre prénom.' : null,
            ),
            WamiTextField(
              hint: 'Nom',
              label: 'Nom',
              icon: Icons.badge_outlined,
              controller: _lastName,
              textInputAction: TextInputAction.next,
              errorText: _submitted && _lastName.text.trim().isEmpty ? 'Indiquez votre nom.' : null,
            ),
            Row(
              children: [
                WamiChip(
                  label: 'Homme',
                  icon: Icons.male_rounded,
                  selected: _gender == Gender.male,
                  expand: true,
                  onTap: () => setState(() => _gender = Gender.male),
                ),
                const SizedBox(width: 8),
                WamiChip(
                  label: 'Femme',
                  icon: Icons.female_rounded,
                  selected: _gender == Gender.female,
                  expand: true,
                  onTap: () => setState(() => _gender = Gender.female),
                ),
              ],
            ),
            if (missingGender)
              Text('Choisissez votre genre.', style: TextStyle(fontSize: 12, color: context.wami.danger)),
          ],
        ),
        _FormSection(
          label: 'Sécurité',
          children: [
            WamiTextField(
              hint: 'Choisissez un mot de passe',
              label: 'Mot de passe',
              icon: Icons.lock_outline_rounded,
              controller: _password,
              obscureText: _hidden,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              suffix: _VisibilityToggle(hidden: _hidden, onToggle: () => setState(() => _hidden = !_hidden)),
            ),
            _PasswordRules(password: _password.text, highlightMissing: _submitted),
          ],
        ),
        _FormSection(
          label: 'Facultatif',
          children: [
            WamiTextField(
              hint: 'Adresse e-mail',
              label: 'E-mail',
              icon: Icons.mail_outline_rounded,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            WamiTextField(
              hint: 'Code de parrainage',
              label: 'Parrainage',
              icon: Icons.card_giftcard_rounded,
              controller: _referral,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
        WamiPrimaryButton(
          label: 'Créer mon compte',
          icon: Icons.check_rounded,
          loading: widget.state.busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// Groupe de champs en verre, avec son sur-titre.
class _FormSection extends StatelessWidget {
  const _FormSection({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(WamiSpace.s4),
      child: Gap(gap: WamiSpace.s3, children: [SectionLabel(label), ...children]),
    );
  }
}

/// Règles du mot de passe, cochées au fil de la saisie (mêmes règles que [PasswordPolicy]).
class _PasswordRules extends StatelessWidget {
  const _PasswordRules({required this.password, required this.highlightMissing});
  final String password;

  /// Après un essai d'envoi, les règles non respectées passent en rouge.
  final bool highlightMissing;

  @override
  Widget build(BuildContext context) {
    final rules = [
      ('${PasswordPolicy.minLength} caractères minimum', password.length >= PasswordPolicy.minLength),
      ('Une majuscule', RegExp('[A-Z]').hasMatch(password)),
      ('Une minuscule', RegExp('[a-z]').hasMatch(password)),
      ('Un chiffre', RegExp('[0-9]').hasMatch(password)),
    ];
    final p = context.wami;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (label, ok) in rules)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: WamiMotion.fast,
                child: Icon(
                  ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  key: ValueKey(ok),
                  size: 16,
                  color: ok ? p.success : (highlightMissing ? p.danger : p.inkMuted),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: ok ? FontWeight.w600 : FontWeight.w400,
                  color: ok ? p.ink : (highlightMissing ? p.danger : p.inkMuted),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({required this.hidden, required this.onToggle});
  final bool hidden;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: hidden ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
      icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
      onPressed: onToggle,
    );
  }
}

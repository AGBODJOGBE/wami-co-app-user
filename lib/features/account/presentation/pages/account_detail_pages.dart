import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/wami_colors.dart';
import '../../../../core/theme/wami_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/password_policy.dart';
import '../../../../core/utils/load_status.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../../../core/widgets/wami_selectors.dart';
import '../../../../core/widgets/wami_text_field.dart';
import '../../domain/entities/app_settings.dart';
import '../cubit/profile_cubit.dart';
import 'profile_extras.dart';
import '../cubit/security_cubit.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/support_cubit.dart';

// ─── Mon profil ──────────────────────────────────────────────────────────────

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final _profile = context.read<ProfileCubit>().state.profile;
  late final _name = TextEditingController(text: _profile?.fullName);
  late final _phone = TextEditingController(text: _profile?.phone);
  late final _email = TextEditingController(text: _profile?.email);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return BlocConsumer<ProfileCubit, ProfileState>(
      listenWhen: (a, b) => a.saveStatus != b.saveStatus || b.notice != null || b.failure != null,
      listener: (context, state) {
        if (state.saveStatus == LoadStatus.ready) showWamiMessage(context, 'Profil enregistré');
        final message = state.notice ?? state.failure?.message;
        if (message != null) showWamiMessage(context, message);
      },
      builder: (context, state) {
        final p = state.profile;
        return WamiScreen(
          title: 'Mon profil',
          body: p == null
              ? const WamiLoading()
              : Gap(
                  children: [
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          WamiAvatar(initials: Fmt.initials(p.fullName), size: 84),
                          Positioned(
                            right: -6,
                            bottom: -4,
                            child: WamiIconButton(
                              icon: Icons.photo_camera_outlined,
                              tooltip: 'Changer la photo',
                              size: 34,
                              color: context.wami.orangeStrong,
                              onPressed: () => showWamiMessage(context, 'Photo de profil : à brancher (image_picker)'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    WamiTextField(hint: 'Nom complet', label: 'Nom complet', controller: _name),
                    WamiTextField(
                      hint: 'Téléphone',
                      label: 'Téléphone',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                    ),
                    WamiTextField(
                      hint: 'E-mail',
                      label: 'E-mail',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    VerificationBanners(profile: p),
                    const SectionLabel('Civilité'),
                    GenderPicker(gender: p.gender),
                    const SectionLabel('Adresse'),
                    AddressCard(address: p.address),
                    const SectionLabel('Adresses favorites'),
                    GlassGroup(
                      children: [
                        for (final s in p.savedPlaces)
                          ListTile(
                            leading: IconBadge(s.label == 'Maison' ? Icons.home_rounded : Icons.work_rounded),
                            title: Text(s.label, style: t.titleSmall),
                            subtitle: Text(s.address, style: t.bodySmall),
                          ),
                      ],
                    ),
                    const SectionLabel('Contact d’urgence'),
                    GlassCard(
                      child: Row(
                        children: [
                          const IconBadge(Icons.health_and_safety_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.emergencyContact ?? 'Ajouter un proche', style: t.titleSmall),
                                Text('Reçoit vos trajets partagés', style: t.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          bottom: WamiPrimaryButton(
            label: 'Enregistrer',
            loading: state.saveStatus == LoadStatus.loading,
            onPressed: () => context.read<ProfileCubit>().save(
                  fullName: _name.text,
                  phone: _phone.text,
                  email: _email.text,
                ),
          ),
        );
      },
    );
  }
}

// ─── Paramètres ──────────────────────────────────────────────────────────────

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final s = state.settings;
        return WamiScreen(
          title: 'Paramètres',
          body: Gap(
            children: [
              const SectionLabel('Apparence'),
              WamiSegmented<AppThemeMode>(
                options: [for (final m in AppThemeMode.values) (m, m.label)],
                value: s.themeMode,
                onChanged: (m) => cubit.update((s) => s.copyWith(themeMode: m)),
              ),
              const SectionLabel('Notifications'),
              GlassGroup(
                children: [
                  ToggleRow(
                    title: 'Courses & livraisons',
                    subtitle: 'Arrivée du chauffeur, suivi du colis',
                    value: s.notifyTrips,
                    onChanged: (v) => cubit.update((s) => s.copyWith(notifyTrips: v)),
                  ),
                  ToggleRow(
                    title: 'Portefeuille',
                    subtitle: 'Recharges, transferts reçus',
                    value: s.notifyWallet,
                    onChanged: (v) => cubit.update((s) => s.copyWith(notifyWallet: v)),
                  ),
                  ToggleRow(
                    title: 'Offres & nouveautés',
                    subtitle: 'Bannières et promotions',
                    value: s.notifyPromos,
                    onChanged: (v) => cubit.update((s) => s.copyWith(notifyPromos: v)),
                  ),
                ],
              ),
              const SectionLabel('Sécurité & trajets'),
              GlassGroup(
                children: [
                  ToggleRow(
                    title: 'Partage auto du trajet',
                    subtitle: 'Avec votre contact d’urgence',
                    value: s.autoShareTrip,
                    onChanged: (v) => cubit.update((s) => s.copyWith(autoShareTrip: v)),
                  ),
                  ToggleRow(
                    title: 'Empreinte / visage',
                    subtitle: 'Pour valider les paiements',
                    value: s.biometrics,
                    onChanged: (v) => cubit.update((s) => s.copyWith(biometrics: v)),
                  ),
                ],
              ),
              const SectionLabel('Langue'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final l in AppLanguage.values)
                    WamiChip(
                      label: l.label,
                      selected: s.language == l,
                      onTap: () => cubit.update((s) => s.copyWith(language: l)),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Assistance ──────────────────────────────────────────────────────────────

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SupportCubit>()..load(),
      child: BlocBuilder<SupportCubit, SupportState>(
        builder: (context, state) {
          final t = Theme.of(context).textTheme;
          final cubit = context.read<SupportCubit>();
          final items = state.filtered;
          return WamiScreen(
            title: 'Assistance',
            body: Gap(
              children: [
                Text('Comment pouvons-nous aider ?', style: t.titleMedium),
                WamiTextField(hint: 'Rechercher une question', icon: Icons.search_rounded, onChanged: cubit.search),
                Row(
                  children: [
                    Expanded(
                      child: _SupportTile(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Écrire au support',
                        subtitle: 'Réponse en ~[N] min',
                        onTap: () => showWamiMessage(context, 'Messagerie support : à brancher'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SupportTile(
                        icon: Icons.sos_rounded,
                        title: 'Urgence',
                        subtitle: 'Pendant une course',
                        danger: true,
                        onTap: () => showWamiMessage(context, 'Numéro d’urgence : à valider'),
                      ),
                    ),
                  ],
                ),
                const SectionLabel('Questions fréquentes'),
                if (state.faq.isEmpty) const SizedBox(height: 120, child: WamiLoading()),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            key: ValueKey('faq-$i-${state.query}'),
                            initiallyExpanded: i == state.openIndex,
                            onExpansionChanged: (_) => cubit.toggle(i),
                            title: Text(
                              items[i].question,
                              style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                            iconColor: WamiColors.orangeLight,
                            collapsedIconColor: WamiColors.orangeLight,
                            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            children: [
                              Text(items[i].answer, style: t.bodySmall?.copyWith(fontSize: 12.5, height: 1.45)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  const _SupportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = danger ? context.wami.danger : context.wami.orangeStrong;
    return GlassCard(
      onTap: onTap,
      borderColor: danger ? color.withValues(alpha: 0.45) : null,
      gradient: danger ? LinearGradient(colors: [color.withValues(alpha: 0.20), color.withValues(alpha: 0.05)]) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon, color: color),
          const SizedBox(height: 8),
          Text(title, style: t.titleSmall),
          Text(subtitle, style: t.bodySmall?.copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }
}

// ─── Confidentialité ─────────────────────────────────────────────────────────

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<SupportCubit>()),
        BlocProvider(create: (_) => sl<SecurityCubit>()),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final s = state.settings;
          final cubit = context.read<SettingsCubit>();
          return WamiScreen(
            title: 'Confidentialité',
            body: Gap(
              children: [
                GlassCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const IconBadge(Icons.shield_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Vous choisissez ce que WAMI utilise. Vos données ne sont jamais vendues. '
                          '[Engagement à valider juridiquement]',
                          style: t.bodySmall?.copyWith(fontSize: 12.5, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionLabel('Vos données'),
                GlassGroup(
                  children: [
                    ToggleRow(
                      title: 'Localisation',
                      subtitle: 'Uniquement pendant l’utilisation',
                      value: s.location,
                      onChanged: (v) => cubit.update((s) => s.copyWith(location: v)),
                    ),
                    ToggleRow(
                      title: 'Suggestions personnalisées',
                      subtitle: 'Destinations et offres adaptées',
                      value: s.personalized,
                      onChanged: (v) => cubit.update((s) => s.copyWith(personalized: v)),
                    ),
                    ToggleRow(
                      title: 'Partage avec les partenaires',
                      subtitle: 'Hôtels, compagnies de bus',
                      value: s.partnerSharing,
                      onChanged: (v) => cubit.update((s) => s.copyWith(partnerSharing: v)),
                    ),
                  ],
                ),
                const SectionLabel('Documents'),
                Builder(
                  builder: (context) => GlassGroup(
                    children: [
                      ListTile(
                        leading: const IconBadge(Icons.description_outlined),
                        title: Text('Politique de confidentialité', style: t.titleSmall),
                        subtitle: Text('Texte juridique à valider', style: t.bodySmall),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {},
                      ),
                      ListTile(
                        leading: const IconBadge(Icons.gavel_rounded),
                        title: Text('Conditions d’utilisation', style: t.titleSmall),
                        subtitle: Text('Texte juridique à valider', style: t.bodySmall),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {},
                      ),
                      ListTile(
                        leading: const IconBadge(Icons.download_rounded),
                        title: Text('Télécharger mes données', style: t.titleSmall),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          await context.read<SupportCubit>().exportData();
                          if (context.mounted) showWamiMessage(context, 'Lien envoyé par e-mail');
                        },
                      ),
                    ],
                  ),
                ),
                GlassGroup(
                  children: [
                    ListTile(
                      leading: IconBadge(Icons.delete_outline_rounded, color: context.wami.danger),
                      title: Text('Supprimer mon compte', style: t.titleSmall?.copyWith(color: context.wami.danger)),
                      onTap: () => _confirmDeleteAccount(context),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Suppression du compte : le mot de passe confirme l'intention. Le délai légal reste à valider.
Future<void> _confirmDeleteAccount(BuildContext context) async {
  final cubit = context.read<SecurityCubit>();
  final password = await showDialog<String>(context: context, builder: (_) => const _DeleteAccountDialog());
  if (password == null) return;
  await cubit.deleteAccount(password);
  if (!context.mounted) return;
  final failure = cubit.state.failure;
  // Succès : la session se termine et le routeur ramène à la connexion.
  if (failure != null) showWamiMessage(context, failure.message);
}

/// Fenêtre de confirmation. Elle possède son champ de saisie : le libérer depuis l'extérieur le ferait
/// servir après sa destruction pendant l'animation de fermeture.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Supprimer mon compte ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cette action est définitive : votre profil et l’accès à votre portefeuille seront supprimés. '
            'Rechargez ou dépensez votre solde avant. Délai légal de conservation : [à valider].',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mot de passe'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(context, _password.text), child: const Text('Supprimer')),
      ],
    );
  }
}

// ─── Mot de passe ────────────────────────────────────────────────────────────

class ChangePasswordPage extends StatelessWidget {
  const ChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => sl<SecurityCubit>(), child: const _ChangePasswordView());
  }
}

class _ChangePasswordView extends StatefulWidget {
  const _ChangePasswordView();

  @override
  State<_ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<_ChangePasswordView> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirmation = TextEditingController();
  bool _hidden = true;
  bool _submitted = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    setState(() => _submitted = true);
    context.read<SecurityCubit>().changePassword(
          current: _current.text,
          next: _next.text,
          confirmation: _confirmation.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SecurityCubit, SecurityState>(
      listenWhen: (a, b) => a.status != b.status,
      listener: (context, state) {
        if (state.status == LoadStatus.ready) {
          showWamiMessage(context, 'Mot de passe modifié.');
          context.pop();
        } else if (state.status == LoadStatus.failure) {
          showWamiMessage(context, state.failure!.message);
        }
      },
      builder: (context, state) {
        final toggle = IconButton(
          tooltip: _hidden ? 'Afficher' : 'Masquer',
          icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
          onPressed: () => setState(() => _hidden = !_hidden),
        );
        return WamiScreen(
          title: 'Mot de passe',
          subtitle: 'Choisissez un mot de passe que vous n’utilisez nulle part ailleurs.',
          body: Gap(
            children: [
              WamiTextField(
                hint: 'Mot de passe actuel',
                label: 'Mot de passe actuel',
                icon: Icons.lock_outline_rounded,
                controller: _current,
                obscureText: _hidden,
                autofocus: true,
                suffix: toggle,
              ),
              WamiTextField(
                hint: '8 caractères, majuscule, minuscule, chiffre',
                label: 'Nouveau mot de passe',
                icon: Icons.lock_reset_rounded,
                controller: _next,
                obscureText: _hidden,
                errorText: _submitted && _next.text.isNotEmpty ? PasswordPolicy.check(_next.text) : null,
                onChanged: (_) {
                  if (_submitted) setState(() {});
                },
              ),
              WamiTextField(
                hint: 'Confirmer le nouveau mot de passe',
                label: 'Confirmation',
                icon: Icons.lock_reset_rounded,
                controller: _confirmation,
                obscureText: _hidden,
                onSubmitted: (_) => _submit(context),
              ),
            ],
          ),
          bottom: WamiPrimaryButton(
            label: 'Modifier le mot de passe',
            loading: state.busy,
            onPressed: () => _submit(context),
          ),
        );
      },
    );
  }
}

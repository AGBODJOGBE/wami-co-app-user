import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/wami_colors.dart';
import '../../../../core/theme/wami_palette.dart';
import '../../../../core/widgets/wami_background.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../cubit/update_cubit.dart';

/// Enveloppe l'application : revérifie la version au retour dans l'application, affiche un rappel facultatif,
/// et bloque tout derrière l'écran de mise à jour quand elle est obligatoire.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});
  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<UpdateCubit>().check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // L'application peut rester des jours en arrière-plan : une version obligatoire a pu sortir entre-temps.
    if (state == AppLifecycleState.resumed) context.read<UpdateCubit>().check();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UpdateCubit, UpdateState>(
      builder: (context, state) {
        return Stack(
          children: [
            widget.child,
            if (state.reminder)
              Positioned(left: 12, right: 12, top: 0, child: SafeArea(child: _Reminder(state: state))),
            if (state.blocking) Positioned.fill(child: _UpdateRequired(state: state)),
          ],
        );
      },
    );
  }
}

class _Reminder extends StatelessWidget {
  const _Reminder({required this.state});
  final UpdateState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.wami;
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xF20C1527) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.glassBorder),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: WamiColors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Nouvelle version disponible', style: t.titleSmall),
                  Text('WAMI ${state.status?.latestVersion ?? ''}', style: t.bodySmall),
                ],
              ),
            ),
            TextButton(onPressed: () => context.read<UpdateCubit>().dismissReminder(), child: const Text('Plus tard')),
            FilledButton(onPressed: () => context.read<UpdateCubit>().openStore(), child: const Text('Mettre à jour')),
          ],
        ),
      ),
    );
  }
}

class _UpdateRequired extends StatelessWidget {
  const _UpdateRequired({required this.state});
  final UpdateState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final status = state.status;
    // Pas de retour possible : l'application ne fonctionne plus avec cette version.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: WamiBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  const Center(child: WamiLogo(height: 34)),
                  const SizedBox(height: 28),
                  const Center(child: IconBadge(Icons.system_update_rounded)),
                  const SizedBox(height: 18),
                  Text('Mise à jour nécessaire', style: t.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Text(
                    'Cette version de WAMI n’est plus prise en charge. Installez la dernière version pour continuer.',
                    style: t.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Version installée : ${status.currentVersion} · Dernière version : ${status.latestVersion}',
                      style: t.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    if (status.releaseNotes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(status.releaseNotes, style: t.bodySmall, textAlign: TextAlign.center),
                    ],
                  ],
                  if (state.openFailed) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Impossible d’ouvrir le magasin d’applications. Cherchez WAMI directement dans le magasin.',
                      style: t.bodySmall?.copyWith(color: context.wami.danger),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const Spacer(),
                  WamiPrimaryButton(
                    label: 'Mettre à jour',
                    icon: Icons.open_in_new_rounded,
                    onPressed: () => context.read<UpdateCubit>().openStore(),
                  ),
                  const SizedBox(height: 8),
                  WamiGhostButton(
                    label: 'Vérifier à nouveau',
                    onPressed: () => context.read<UpdateCubit>().check(force: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

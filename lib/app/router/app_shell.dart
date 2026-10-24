import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/wami_colors.dart';
import '../../core/theme/wami_palette.dart';
import '../../core/theme/wami_tokens.dart';

/// Coque des 4 onglets avec la barre de navigation flottante en verre.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (Icons.home_rounded, 'Accueil'),
    (Icons.show_chart_rounded, 'Activités'),
    (Icons.account_balance_wallet_rounded, 'Portefeuille'),
    (Icons.person_rounded, 'Compte'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _FloatingNav(
          index: navigationShell.currentIndex,
          onTap: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
        ),
      ),
    );
  }
}

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.wami;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: context.isDark ? const Color(0xCC0C1527) : const Color(0xE6FFFFFF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: p.glassBorder),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 12))],
          ),
          child: Row(
            children: [
              for (var i = 0; i < AppShell._tabs.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    label: AppShell._tabs[i].$2,
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => onTap(i),
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: WamiMotion.base,
                            width: 40,
                            height: 28,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: i == index ? WamiEffects.ctaGradient : null,
                              boxShadow: i == index
                                  ? [BoxShadow(color: WamiColors.orange.withValues(alpha: 0.55), blurRadius: 16)]
                                  : null,
                            ),
                            child: Icon(
                              AppShell._tabs[i].$1,
                              size: 20,
                              color: i == index ? WamiColors.white : p.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            AppShell._tabs[i].$2,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: i == index ? p.ink : p.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

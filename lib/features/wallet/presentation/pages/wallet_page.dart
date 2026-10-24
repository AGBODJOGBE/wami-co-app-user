import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/wami_colors.dart';
import '../../../../core/theme/wami_palette.dart';
import '../../../../core/theme/wami_tokens.dart';
import '../../../../core/theme/wami_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/load_status.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_background.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../domain/entities/wallet.dart';
import '../bloc/wallet_bloc.dart';

/// Onglet Portefeuille : solde masquable, actions, dernières opérations.
class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return WamiBackground(
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<WalletBloc, WalletState>(
          builder: (context, state) {
            if (state.status == LoadStatus.failure && state.overview == null) {
              return WamiErrorView(
                failure: state.failure!,
                onRetry: () => context.read<WalletBloc>().add(const WalletStarted()),
              );
            }
            final o = state.overview;
            if (o == null) return const WamiLoading();
            return RefreshIndicator(
              onRefresh: () async => context.read<WalletBloc>().add(const WalletStarted()),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(WamiSpace.screen, 12, WamiSpace.screen, 110),
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Portefeuille', style: Theme.of(context).textTheme.headlineSmall)),
                      WamiIconButton(
                        icon: Icons.qr_code_scanner_rounded,
                        tooltip: 'Payer par QR code',
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _BalanceCard(wallet: o.wallet, hidden: state.balanceHidden),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Action(
                        icon: Icons.add_rounded,
                        label: 'Recharger',
                        primary: true,
                        onTap: () => context.push(Routes.walletTopUp),
                      ),
                      _Action(
                        icon: Icons.send_rounded,
                        label: 'Transférer',
                        onTap: () => context.push(Routes.walletTransfer),
                      ),
                      _Action(icon: Icons.qr_code_2_rounded, label: 'Payer', onTap: () {}),
                      _Action(icon: Icons.file_download_outlined, label: 'Retirer', onTap: () {}),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SectionLabel(
                    'Dernières opérations',
                    trailing:
                        TextButton(onPressed: () => context.go(Routes.activities), child: const Text('Tout voir')),
                  ),
                  const SizedBox(height: 4),
                  GlassGroup(children: [for (final t in o.transactions.take(5)) _TxRow(tx: t)]),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet, required this.hidden});
  final Wallet wallet;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(WamiRadius.xl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2F57), Color(0xFF0E1830)],
          stops: [0, 0.7],
        ),
        boxShadow: [
          const BoxShadow(color: Color(0x59000000), blurRadius: 40, offset: Offset(0, 20)),
          BoxShadow(color: WamiColors.orange.withValues(alpha: 0.15), blurRadius: 40),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -60,
            top: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    WamiColors.orangeLight.withValues(alpha: 0.55),
                    WamiColors.orangeLight.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'SOLDE DISPONIBLE',
                      style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD9DEEA),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: hidden ? 'Afficher le solde' : 'Masquer le solde',
                    onPressed: () => context.read<WalletBloc>().add(const WalletBalanceVisibilityToggled()),
                    icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    hidden ? '• • • • •' : Fmt.fcfa(wallet.balance, withUnit: false),
                    style: WamiTypography.number(34, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'F CFA',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: WamiColors.orangePeach),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'WAMI · ${wallet.holder}',
                      style: const TextStyle(color: Color(0xFFC9D0DF), fontSize: 12.5),
                    ),
                  ),
                  WamiTag('Points : ${wallet.points}', tint: Colors.white),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap, this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final p = context.wami;
    return Expanded(
      child: Column(
        children: [
          if (primary)
            GlowOrbButton(icon: icon, tooltip: label, onPressed: onTap, size: 56)
          else
            Material(
              color: p.glass,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: p.glassBorder),
              ),
              child: InkWell(
                onTap: onTap,
                customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: SizedBox.square(dimension: 56, child: Icon(icon, color: p.orangeStrong)),
              ),
            ),
          const SizedBox(height: 7),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx});
  final WalletTransaction tx;

  IconData get _icon => switch (tx.kind) {
        TransactionKind.ride => Icons.local_taxi_rounded,
        TransactionKind.delivery => Icons.inventory_2_outlined,
        TransactionKind.bus => Icons.directions_bus_rounded,
        TransactionKind.lodging => Icons.hotel_rounded,
        TransactionKind.topUp => Icons.south_west_rounded,
        TransactionKind.transferIn => Icons.south_west_rounded,
        TransactionKind.transferOut => Icons.north_east_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final credit = tx.amount > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          IconBadge(_icon, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.label, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 13.5)),
                Text(
                  '${Fmt.relativeDay(tx.date)} · ${Fmt.hhmm(tx.date)}',
                  style: t.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          Text(
            Fmt.fcfa(tx.amount, signed: true),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: credit ? context.wami.success : null),
          ),
        ],
      ),
    );
  }
}

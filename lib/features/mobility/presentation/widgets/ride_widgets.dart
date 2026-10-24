import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/wami_colors.dart';
import '../../../../core/theme/wami_palette.dart';
import '../../../../core/theme/wami_tokens.dart';
import '../../../../core/theme/wami_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../domain/entities/ride.dart';
import '../../domain/entities/vehicle_offer.dart';
import '../../domain/entities/waiting_policy.dart';

/// Ligne d'offre : illustration 3D, gamme, délai, prix. Surbrillance si choisie.
class OfferTile extends StatelessWidget {
  const OfferTile({super.key, required this.offer, required this.selected, required this.onTap});
  final VehicleOffer offer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.wami;
    final t = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      label: '${offer.category.label}, ${Fmt.fcfa(offer.price)}, ${offer.etaMinutes} minutes',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: WamiMotion.base,
          padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected ? WamiEffects.selectedGradient : null,
            color: selected ? null : p.glass,
            border: Border.all(color: selected ? WamiColors.orangeLight.withValues(alpha: 0.85) : p.glassBorder),
            boxShadow: selected ? [BoxShadow(color: WamiColors.orange.withValues(alpha: 0.18), blurRadius: 24)] : null,
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.glass, borderRadius: BorderRadius.circular(14)),
                child: ServiceIllustration(offer.category.art, size: 52),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(offer.category.label, style: t.titleSmall),
                        if (offer.recommended) ...[const SizedBox(width: 6), const WamiTag('Recommandé')],
                      ],
                    ),
                    Text(
                      '${offer.category.hint} · ${offer.etaMinutes} min · ${offer.category.seats} pl.',
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              NumberText(Fmt.fcfa(offer.price), size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte du chauffeur.
class DriverCard extends StatelessWidget {
  const DriverCard({super.key, required this.driver, this.trailing});
  final Driver driver;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        WamiAvatar(initials: Fmt.initials(driver.name)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: Text(driver.name, style: t.titleSmall, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 6),
                  RatingText(driver.rating, size: 12),
                ],
              ),
              Text('${driver.vehicle} · ${driver.plate}', style: t.bodySmall),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Dock de contact (remplace les boutons classiques Appeler / Message / Partager).
///
/// Un champ « Écrire à … » qui s'ouvre sur la messagerie, un orbe d'appel lumineux
/// et un orbe de partage. Affiché uniquement tant que la course n'a pas démarré.
class ContactDock extends StatelessWidget {
  const ContactDock({
    super.key,
    required this.driverName,
    required this.onMessage,
    required this.onCall,
    required this.onShare,
  });

  final String driverName;
  final VoidCallback onMessage;
  final VoidCallback onCall;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final p = context.wami;
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            onTap: onMessage,
            radius: WamiRadius.pill,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 18, color: p.orangeStrong),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Écrire à ${driverName.split(' ').first}…',
                    style: TextStyle(color: p.inkMuted, fontSize: 13.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        GlowOrbButton(icon: Icons.call_rounded, tooltip: 'Appeler le chauffeur', onPressed: onCall),
        const SizedBox(width: 10),
        WamiIconButton(icon: Icons.ios_share_rounded, tooltip: 'Partager le trajet', onPressed: onShare, size: 48),
      ],
    );
  }
}

/// Compteur d'attente : anneau gratuit (blanc) puis payant (orange) et frais en cours.
class WaitingMeter extends StatelessWidget {
  const WaitingMeter({super.key, required this.waitedSeconds, required this.fee, required this.policy});
  final int waitedSeconds;
  final int fee;
  final WaitingPolicy policy;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final freeLeft = policy.freeLeft(waitedSeconds);
    final billing = freeLeft == 0;
    return GlassCard(
      child: Row(
        children: [
          SizedBox.square(
            dimension: 76,
            child: CustomPaint(
              painter: _MeterPainter(
                waited: waitedSeconds,
                free: policy.freeWaitingSeconds,
                track: context.wami.ink.withValues(alpha: 0.10),
              ),
              child: Center(child: NumberText(Fmt.clock(waitedSeconds), size: 15)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(billing ? 'Attente facturée' : 'Votre chauffeur est arrivé', style: t.titleSmall),
                const SizedBox(height: 2),
                Text(
                  billing
                      ? '${Fmt.fcfa(policy.waitingRatePerMinute)} par minute entamée'
                      : 'Attente gratuite encore ${Fmt.clock(freeLeft)}',
                  style: t.bodySmall,
                ),
                const SizedBox(height: 6),
                if (billing)
                  NumberText('+ ${Fmt.fcfa(fee)}', size: 16, color: WamiColors.orangeLight)
                else
                  Text(
                    'Rejoignez-le vite pour ne rien payer',
                    style: t.bodySmall?.copyWith(color: context.wami.orangeStrong),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  _MeterPainter({required this.waited, required this.free, required this.track});
  final int waited;
  final int free;
  final Color track;

  /// L'anneau complet représente 5 minutes.
  static const _span = 300;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(5);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, math.pi * 2, false, base..color = track);
    const start = -math.pi / 2;
    final freeSweep = math.min(waited, free) / _span * math.pi * 2;
    canvas.drawArc(arc, start, freeSweep, false, base..color = const Color(0xCCFFFFFF));
    if (waited > free) {
      final paidSweep = (math.min(waited, _span) - free) / _span * math.pi * 2;
      canvas.drawArc(arc, start + freeSweep, paidSweep, false, base..color = WamiColors.orangeLight);
    }
  }

  @override
  bool shouldRepaint(_MeterPainter old) => old.waited != waited || old.track != track;
}

/// Bandeau de pause pendant la course.
class PauseBanner extends StatelessWidget {
  const PauseBanner({super.key, required this.pausedSeconds, required this.fee, required this.policy});
  final int pausedSeconds;
  final int fee;
  final WaitingPolicy policy;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GlassCard(
      borderColor: WamiColors.glowHebergement.withValues(alpha: 0.6),
      gradient: LinearGradient(
        colors: [
          WamiColors.glowHebergement.withValues(alpha: 0.18),
          WamiColors.glowHebergement.withValues(alpha: 0.04),
        ],
      ),
      child: Row(
        children: [
          const IconBadge(Icons.pause_rounded, color: WamiColors.glowHebergement, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Le chauffeur a mis la course en pause', style: t.titleSmall),
                Text(
                  policy.pauseBilled
                      ? 'Pause facturée ${Fmt.fcfa(policy.pauseRatePerMinute)}/min · à valider'
                      : 'Pause non facturée',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              NumberText(Fmt.clock(pausedSeconds), size: 15),
              if (fee > 0)
                Text('+ ${Fmt.fcfa(fee)}', style: WamiTypography.number(12, color: WamiColors.glowHebergement)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Radar animé pendant la recherche du chauffeur.
class SearchingRadar extends StatefulWidget {
  const SearchingRadar({super.key});

  @override
  State<SearchingRadar> createState() => _SearchingRadarState();
}

class _SearchingRadarState extends State<SearchingRadar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 120,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(painter: _RadarPainter(_c.value)),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final v = (t + i / 3) % 1;
      canvas.drawCircle(
        c,
        14 + v * 46,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = WamiColors.orangeLight.withValues(alpha: (1 - v) * 0.7),
      );
    }
    canvas.drawCircle(c, 12, Paint()..color = WamiColors.orangeLight);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t;
}

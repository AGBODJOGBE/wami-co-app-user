import 'package:flutter/material.dart';

import '../../../../core/theme/wami_colors.dart';
import '../../../../core/theme/wami_palette.dart';
import '../../../../core/theme/wami_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../domain/entities/bus.dart';

/// Ligne « 06:30 —— 6 h 30 —— 13:00 ».
class TripTimeline extends StatelessWidget {
  const TripTimeline({super.key, required this.trip, this.fromLabel, this.toLabel});
  final BusTrip trip;
  final String? fromLabel;
  final String? toLabel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NumberText(trip.departure, size: 17),
            if (fromLabel != null) Text(fromLabel!, style: t.bodySmall),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0x59FFFFFF), WamiColors.glowBus]),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  color: context.wami.surface,
                  child: Text(Fmt.duration(trip.durationMinutes), style: t.bodySmall?.copyWith(fontSize: 10.5)),
                ),
              ],
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            NumberText(trip.arrival, size: 17),
            if (toLabel != null) Text(toLabel!, style: t.bodySmall),
          ],
        ),
      ],
    );
  }
}

/// Carte d'un départ, avec case « comparer ».
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.isBest,
    required this.inCompare,
    required this.onTap,
    required this.onToggleCompare,
  });

  final BusTrip trip;
  final bool isBest;
  final bool inCompare;
  final VoidCallback onTap;
  final VoidCallback onToggleCompare;

  @override
  Widget build(BuildContext context) {
    final p = context.wami;
    final t = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WamiRadius.card),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WamiRadius.card),
            border: Border.all(color: isBest ? WamiColors.orangeLight.withValues(alpha: 0.6) : p.glassBorder),
            gradient: isBest
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [WamiColors.orange.withValues(alpha: 0.16), p.glass],
                  )
                : null,
            color: isBest ? null : p.glass,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Flexible(child: Text(trip.company, style: t.titleSmall, overflow: TextOverflow.ellipsis)),
                  if (isBest) ...[const SizedBox(width: 8), const WamiTag('Meilleur choix')],
                  const Spacer(),
                  Semantics(
                    label: 'Ajouter au comparatif',
                    checked: inCompare,
                    child: InkWell(
                      onTap: onToggleCompare,
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: WamiMotion.fast,
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: inCompare ? WamiEffects.ctaGradient : null,
                          border: inCompare ? null : Border.all(color: p.ink.withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: inCompare ? const Icon(Icons.check_rounded, size: 16, color: WamiColors.white) : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TripTimeline(trip: trip),
              const SizedBox(height: 10),
              Row(
                children: [
                  RatingText(trip.rating, size: 12),
                  Text('  ·  ${trip.comfort.label}  ·  ${trip.seatsLeft} places', style: t.bodySmall),
                  const Spacer(),
                  NumberText(Fmt.fcfa(trip.price), size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// QR code du billet.
///
/// Rendu décoratif dérivé de la référence. En production, générer le vrai code
/// avec le paquet `qr_flutter` à partir de [payload] — à valider.
class TicketQr extends StatelessWidget {
  const TicketQr({super.key, required this.payload, this.size = 104});
  final String payload;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'QR code du billet',
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: CustomPaint(size: Size.square(size), painter: _QrPainter(payload.hashCode)),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.seed);
  final int seed;

  static const _n = 25;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _n;
    final paint = Paint()..color = WamiColors.night;
    void finder(int x, int y) {
      canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, 7 * cell, 7 * cell), paint);
      canvas.drawRect(Rect.fromLTWH((x + 1) * cell, (y + 1) * cell, 5 * cell, 5 * cell), Paint()..color = Colors.white);
      canvas.drawRect(Rect.fromLTWH((x + 2) * cell, (y + 2) * cell, 3 * cell, 3 * cell), paint);
    }

    finder(0, 0);
    finder(18, 0);
    finder(0, 18);
    var s = seed.abs() % 233280;
    for (var y = 0; y < _n; y++) {
      for (var x = 0; x < _n; x++) {
        final inFinder = (x < 8 && y < 8) || (x > 16 && y < 8) || (x < 8 && y > 16);
        s = (s * 9301 + 49297) % 233280;
        if (!inFinder && s / 233280 > 0.52) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.seed != seed;
}

import 'package:flutter/material.dart';

import '../../../../core/domain/service_type.dart';
import '../../../../core/theme/wami_colors.dart';
import '../../../../core/theme/wami_palette.dart';
import '../../../../core/theme/wami_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../domain/entities/lodging.dart';

ServiceArt artFor(LodgingType t) => switch (t) {
      LodgingType.hotel => ServiceArt.hotel,
      LodgingType.room => ServiceArt.chambre,
      LodgingType.apartment => ServiceArt.appartement,
    };

IconData amenityIcon(Amenity a) => switch (a) {
      Amenity.airConditioning => Icons.ac_unit_rounded,
      Amenity.wifi => Icons.wifi_rounded,
      Amenity.generator => Icons.bolt_rounded,
      Amenity.security => Icons.verified_user_outlined,
      Amenity.parking => Icons.local_parking_rounded,
      Amenity.furnished => Icons.weekend_outlined,
      Amenity.runningWater => Icons.water_drop_outlined,
    };

/// Visuel d'en-tête : illustration 3D sur fond lumineux (en attendant les photos).
class LodgingHero extends StatelessWidget {
  const LodgingHero({super.key, required this.lodging, this.height = 132, this.child, this.artSize = 120});
  final Lodging lodging;
  final double height;
  final double artSize;
  final Widget? child;

  static const _glows = [WamiColors.glowHebergement, WamiColors.orange, WamiColors.glowLivraison];

  @override
  Widget build(BuildContext context) {
    final glow = _glows[lodging.id.hashCode.abs() % _glows.length];
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.bottomCenter,
                radius: 0.9,
                colors: [glow.withValues(alpha: 0.45), glow.withValues(alpha: 0)],
              ),
              color: const Color(0xFF16244A),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: const Offset(0, 8),
              child: ServiceIllustration(artFor(lodging.type), size: artSize),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00070D1A), Color(0xD9070D1A)],
                stops: [0.4, 1],
              ),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class LodgingCard extends StatelessWidget {
  const LodgingCard({
    super.key,
    required this.lodging,
    required this.favorite,
    required this.onTap,
    required this.onFavorite,
    this.topPick = false,
  });

  final Lodging lodging;
  final bool favorite;
  final bool topPick;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.wami;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: p.glass,
            border: Border.all(color: p.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: LodgingHero(
                  lodging: lodging,
                  child: Stack(
                    children: [
                      if (topPick) const Positioned(top: 10, left: 10, child: WamiTag('Idéal pour vous')),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: IconButton(
                          tooltip: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                          onPressed: onFavorite,
                          icon: Icon(
                            favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: favorite ? WamiColors.orangeLight : WamiColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(lodging.name, style: t.titleSmall?.copyWith(fontSize: 14.5))),
                        RatingText(lodging.rating),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: Text(lodging.area, style: t.bodySmall, overflow: TextOverflow.ellipsis)),
                        NumberText(Fmt.fcfa(lodging.price), size: 15),
                        Text(' ${lodging.priceUnit}', style: t.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AmenityRow extends StatelessWidget {
  const AmenityRow({super.key, required this.amenities});
  final Iterable<Amenity> amenities;

  @override
  Widget build(BuildContext context) {
    final p = context.wami;
    return Row(
      children: [
        for (final a in amenities.take(4))
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: p.glass,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: p.glassBorder),
                  ),
                  child: Icon(amenityIcon(a), size: 20, color: WamiColors.star),
                ),
                const SizedBox(height: 6),
                Text(a.label, style: TextStyle(fontSize: 11, color: p.inkMuted)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Créneau de visite.
class SlotButton extends StatelessWidget {
  const SlotButton({super.key, required this.slot, required this.selected, required this.onTap});
  final VisitSlot slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.wami;
    return Opacity(
      opacity: slot.available ? 1 : 0.3,
      child: Semantics(
        button: true,
        selected: selected,
        enabled: slot.available,
        label: '${slot.day} ${slot.time}${slot.available ? '' : ', complet'}',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: WamiMotion.fast,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: selected ? WamiColors.orange.withValues(alpha: 0.18) : p.glass,
              border: Border.all(color: selected ? WamiColors.orangeLight.withValues(alpha: 0.85) : p.glassBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(slot.day, style: TextStyle(fontSize: 11, color: p.inkMuted)),
                Text(
                  slot.time,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    decoration: slot.available ? null : TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

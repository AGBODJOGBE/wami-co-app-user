import 'package:flutter/painting.dart';

import '../theme/wami_colors.dart';

/// Illustrations 3D du design system (assets/illustrations).
enum ServiceArt {
  moto('moto', 'Moto'),
  auto('auto', 'Voiture'),
  colis('colis', 'Colis'),
  bus('bus', 'Bus'),
  hotel('hotel', 'Hôtel'),
  chambre('chambre', 'Chambre'),
  appartement('appartement', 'Appartement');

  const ServiceArt(this.file, this.label);
  final String file;
  final String label;

  String get assetPath => 'assets/illustrations/illustration-$file.svg';
}

/// Les quatre univers de la super app. Une nouvelle activité = une nouvelle valeur.
enum ServiceType {
  mobility('Mobilité', 'Moto, auto, VIP', ServiceArt.moto, WamiColors.glowMobilite),
  delivery('Livraison', 'Colis en ville', ServiceArt.colis, WamiColors.glowLivraison),
  bus('Bus', 'Billets interurbains', ServiceArt.bus, WamiColors.glowBus),
  lodging('Hébergement', 'Hôtel, chambre, appart.', ServiceArt.hotel, WamiColors.glowHebergement);

  const ServiceType(this.label, this.tagline, this.art, this.glow);
  final String label;
  final String tagline;
  final ServiceArt art;
  final Color glow;
}

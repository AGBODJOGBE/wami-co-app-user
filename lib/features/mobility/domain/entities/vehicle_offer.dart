import 'package:equatable/equatable.dart';

import '../../../../core/domain/service_type.dart';

/// Gammes de véhicules WAMI.
enum VehicleCategory {
  moto('Moto', 1, ServiceArt.moto, 'Le plus rapide'),
  tricycle('Tricycle', 3, ServiceArt.moto, 'Avec bagages'),
  eco('Éco', 4, ServiceArt.auto, 'Le moins cher'),
  standard('Standard', 4, ServiceArt.auto, 'Économique'),
  confort('Confort', 4, ServiceArt.auto, 'Climatisé'),
  vip('VIP', 4, ServiceArt.auto, 'Haut de gamme'),
  van('Van', 7, ServiceArt.auto, 'Groupes');

  const VehicleCategory(this.label, this.seats, this.art, this.hint);
  final String label;
  final int seats;
  final ServiceArt art;
  final String hint;

  /// Nom du type de véhicule côté back (`MOTO`, `CONFORT`…).
  String get apiName => name.toUpperCase();

  static VehicleCategory? fromApi(String? value) {
    for (final c in values) {
      if (c.apiName == value) return c;
    }
    return null;
  }
}

/// Prix proposé pour une gamme, sur un trajet donné.
class VehicleOffer extends Equatable {
  const VehicleOffer({
    required this.category,
    required this.price,
    this.arrivalMinutes,
    this.nearbyDrivers,
    this.recommended = false,
    this.discount = 0,
  });

  final VehicleCategory category;

  /// Prix à payer, remise du code promo déduite.
  final int price;

  /// Remise du code promo appliquée (0 sans code).
  final int discount;

  /// Prix avant remise.
  int get fullPrice => price + discount;

  /// Délai d'arrivée du chauffeur le plus proche, en minutes. `null` : inconnu (aucun chauffeur proche, ou
  /// information indisponible).
  final int? arrivalMinutes;

  /// Nombre de chauffeurs disponibles autour du départ pour cette gamme (`null` : inconnu).
  final int? nearbyDrivers;

  /// Aucun chauffeur de cette gamme n'est disponible à proximité.
  bool get noDriverNearby => nearbyDrivers == 0;

  /// Choix mis en avant par WAMI (meilleur rapport prix / délai).
  final bool recommended;

  @override
  List<Object?> get props => [category, price, arrivalMinutes, nearbyDrivers, recommended, discount];
}

/// Résultat d'une estimation : les prix, et le motif de refus du code promo s'il a été refusé.
class OfferQuote extends Equatable {
  const OfferQuote({required this.offers, this.promoError});
  final List<VehicleOffer> offers;

  /// Code promo refusé (inconnu, réservé aux nouveaux clients…) : les prix sont alors sans remise.
  final String? promoError;

  @override
  List<Object?> get props => [offers, promoError];
}

/// Code promo proposé au passager. Seuls le code et son texte sont utiles à l'écran.
class AvailablePromo extends Equatable {
  const AvailablePromo({required this.code, required this.displayText});
  final String code;
  final String displayText;

  @override
  List<Object?> get props => [code, displayText];
}

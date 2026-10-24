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
    required this.etaMinutes,
    this.recommended = false,
  });

  final VehicleCategory category;
  final int price;

  /// Durée estimée du trajet (le back ne donne pas encore le délai d'arrivée du chauffeur à l'estimation).
  final int etaMinutes;

  /// Choix mis en avant par WAMI (meilleur rapport prix / délai).
  final bool recommended;

  @override
  List<Object?> get props => [category, price, etaMinutes, recommended];
}

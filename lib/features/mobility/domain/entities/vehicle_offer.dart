import 'package:equatable/equatable.dart';

import '../../../../core/domain/service_type.dart';

/// Gammes de véhicules WAMI.
enum VehicleCategory {
  moto('Moto', 1, ServiceArt.moto, 'Le plus rapide'),
  tricycle('Tricycle', 3, ServiceArt.moto, 'Avec bagages'),
  standard('Standard', 4, ServiceArt.auto, 'Économique'),
  confort('Confort', 4, ServiceArt.auto, 'Climatisé'),
  vip('VIP', 4, ServiceArt.auto, 'Haut de gamme'),
  van('Van', 7, ServiceArt.auto, 'Groupes');

  const VehicleCategory(this.label, this.seats, this.art, this.hint);
  final String label;
  final int seats;
  final ServiceArt art;
  final String hint;
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
  final int etaMinutes;

  /// Choix mis en avant par WAMI (meilleur rapport prix / délai).
  final bool recommended;

  @override
  List<Object?> get props => [category, price, etaMinutes, recommended];
}

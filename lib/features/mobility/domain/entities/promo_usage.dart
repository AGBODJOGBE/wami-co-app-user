import 'package:equatable/equatable.dart';

/// Un code promo déjà utilisé par le passager, avec la remise obtenue (en FCFA entiers).
class PromoUsage extends Equatable {
  const PromoUsage({required this.code, required this.discount, this.appliedAt});
  final String code;
  final int discount;
  final DateTime? appliedAt;

  @override
  List<Object?> get props => [code, discount, appliedAt];
}

/// Historique d'utilisation des codes promo : les usages, du plus récent au plus ancien, et la remise totale.
class PromoHistory extends Equatable {
  const PromoHistory({this.usages = const [], this.totalDiscount = 0});
  final List<PromoUsage> usages;
  final int totalDiscount;

  @override
  List<Object?> get props => [usages, totalDiscount];
}

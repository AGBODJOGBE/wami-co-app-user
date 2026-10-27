import 'package:equatable/equatable.dart';

class Wallet extends Equatable {
  const Wallet({required this.balance, required this.points, required this.holder});
  final int balance;
  final int points;
  final String holder;

  @override
  List<Object?> get props => [balance, points, holder];
}

enum TransactionKind { ride, delivery, bus, lodging, topUp, transferOut, transferIn }

class WalletTransaction extends Equatable {
  const WalletTransaction({
    required this.id,
    required this.label,
    required this.date,
    required this.amount,
    required this.kind,
  });

  final String id;
  final String label;
  final DateTime date;

  /// Montant signé : positif = crédit, négatif = débit.
  final int amount;
  final TransactionKind kind;

  @override
  List<Object?> get props => [id, label, date, amount, kind];
}

enum TopUpKind { mobileMoney, card }

/// Moyen de recharge enregistré. Le back n'a pas de moyens enregistrés : seul le numéro du compte est proposé
/// en réel ; les cartes restent simulées (voir docs/BACKEND_A_FAIRE.md).
class TopUpSource extends Equatable {
  const TopUpSource({required this.id, required this.kind, required this.label, required this.masked, this.phone});
  final String id;
  final TopUpKind kind;

  /// Opérateur ou réseau de carte (à valider : opérateurs Mobile Money au Bénin).
  final String label;
  final String masked;

  /// Numéro Mobile Money à débiter, au format international. `null` pour une carte.
  final String? phone;

  @override
  List<Object?> get props => [id, kind, label, masked, phone];
}

/// Contact à qui l'on envoie de l'argent. Le back n'a pas de carnet de bénéficiaires (voir docs/BACKEND_A_FAIRE.md).
class Beneficiary extends Equatable {
  const Beneficiary({required this.id, required this.name, required this.phone});
  final String id;
  final String name;

  /// Numéro au format international.
  final String phone;

  @override
  List<Object?> get props => [id, name, phone];
}

class WalletOverview extends Equatable {
  const WalletOverview({required this.wallet, required this.transactions});
  final Wallet wallet;
  final List<WalletTransaction> transactions;

  @override
  List<Object?> get props => [wallet, transactions];
}

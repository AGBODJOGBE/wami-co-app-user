import 'package:equatable/equatable.dart';

class Wallet extends Equatable {
  const Wallet({required this.balance, required this.points, required this.holder, this.affiliateBalance = 0});
  final int balance;
  final int points;
  final String holder;

  /// Gains d'affilié (code promo d'un influenceur) : retirables, jamais dépensables. Exclus de [balance].
  final int affiliateBalance;

  @override
  List<Object?> get props => [balance, points, holder, affiliateBalance];
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

enum WithdrawMethod {
  mobileMoney('MOBILE_MONEY', 'Mobile Money', 1000),
  bank('BANK_TRANSFER', 'Virement bancaire', 5000);

  const WithdrawMethod(this.api, this.label, this.defaultMinimum);
  final String api;
  final String label;

  /// Minimum appliqué par défaut par le back (modifiable par l'administration) : le back reste juge.
  final int defaultMinimum;
}

/// Demande de retrait des gains d'affilié.
class WithdrawRequest extends Equatable {
  const WithdrawRequest({
    required this.amount,
    required this.method,
    this.phone,
    this.bankName,
    this.accountName,
    this.iban,
  });

  final int amount;
  final WithdrawMethod method;

  /// Numéro Mobile Money, au format international.
  final String? phone;
  final String? bankName;
  final String? accountName;
  final String? iban;

  @override
  List<Object?> get props => [amount, method, phone, bankName, accountName, iban];
}

/// Retrait pris en compte par le back : il est traité ensuite par l'équipe.
class Withdrawal extends Equatable {
  const Withdrawal({required this.id, required this.amount, this.message});
  final String id;
  final int amount;
  final String? message;

  @override
  List<Object?> get props => [id, amount, message];
}

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

class WalletOverview extends Equatable {
  const WalletOverview({required this.wallet, required this.transactions});
  final Wallet wallet;
  final List<WalletTransaction> transactions;

  @override
  List<Object?> get props => [wallet, transactions];
}

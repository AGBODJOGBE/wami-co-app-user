import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/wallet.dart';
import '../repositories/wallet_repository.dart';

/// Limites de montant — à valider (réglementation, plafonds Mobile Money).
abstract final class WalletLimits {
  static const minTopUp = 500;
  static const maxTopUp = 500000;
  static const minTransfer = 100;
}

class GetWalletOverview implements UseCase<WalletOverview, NoParams> {
  const GetWalletOverview(this._repo);
  final WalletRepository _repo;

  @override
  Future<Result<WalletOverview>> call(NoParams _) => _repo.getOverview();
}

class GetTopUpSources implements UseCase<List<TopUpSource>, NoParams> {
  const GetTopUpSources(this._repo);
  final WalletRepository _repo;

  @override
  Future<Result<List<TopUpSource>>> call(NoParams _) => _repo.getTopUpSources();
}

class GetBeneficiaries implements UseCase<List<Beneficiary>, NoParams> {
  const GetBeneficiaries(this._repo);
  final WalletRepository _repo;

  @override
  Future<Result<List<Beneficiary>>> call(NoParams _) => _repo.getBeneficiaries();
}

class TopUpParams {
  const TopUpParams({required this.amount, required this.sourceId});
  final int amount;
  final String sourceId;
}

class TopUpWallet implements UseCase<WalletOverview, TopUpParams> {
  const TopUpWallet(this._repo);
  final WalletRepository _repo;

  @override
  Future<Result<WalletOverview>> call(TopUpParams p) async {
    if (p.amount < WalletLimits.minTopUp) {
      return const Err(ValidationFailure('Montant minimum : ${WalletLimits.minTopUp} F.'));
    }
    if (p.amount > WalletLimits.maxTopUp) {
      return const Err(ValidationFailure('Montant maximum dépassé.'));
    }
    return _repo.topUp(amount: p.amount, sourceId: p.sourceId);
  }
}

class TransferParams {
  const TransferParams({required this.beneficiaryId, required this.amount, required this.currentBalance, this.note});
  final String beneficiaryId;
  final int amount;
  final int currentBalance;
  final String? note;
}

/// Règle métier : impossible de transférer plus que le solde.
class TransferMoney implements UseCase<WalletOverview, TransferParams> {
  const TransferMoney(this._repo);
  final WalletRepository _repo;

  @override
  Future<Result<WalletOverview>> call(TransferParams p) async {
    if (p.amount < WalletLimits.minTransfer) {
      return const Err(ValidationFailure('Montant minimum : ${WalletLimits.minTransfer} F.'));
    }
    if (p.amount > p.currentBalance) return const Err(InsufficientFundsFailure());
    return _repo.transfer(beneficiaryId: p.beneficiaryId, amount: p.amount, note: p.note);
  }
}

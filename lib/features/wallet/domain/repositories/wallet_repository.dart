import '../../../../core/utils/result.dart';
import '../entities/wallet.dart';

abstract interface class WalletRepository {
  Future<Result<WalletOverview>> getOverview();
  Future<Result<List<TopUpSource>>> getTopUpSources();
  Future<Result<List<Beneficiary>>> getBeneficiaries();

  /// Renvoie le nouvel état du portefeuille.
  Future<Result<WalletOverview>> topUp({required int amount, required String sourceId});
  Future<Result<WalletOverview>> transfer({required String beneficiaryId, required int amount, String? note});
}

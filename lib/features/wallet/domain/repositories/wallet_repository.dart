import '../../../../core/utils/result.dart';
import '../entities/wallet.dart';

abstract interface class WalletRepository {
  Future<Result<WalletOverview>> getOverview();
  Future<Result<List<TopUpSource>>> getTopUpSources();
  Future<Result<List<Beneficiary>>> getBeneficiaries();

  /// Recharge par Mobile Money : le serveur envoie une demande de confirmation sur [phone]
  /// et la méthode rend le portefeuille une fois le paiement validé.
  /// [phone] est au format international (`+2290197123456`).
  Future<Result<WalletOverview>> topUp({required int amount, required String phone});

  /// Transfert vers un autre passager WAMI, identifié par son numéro (format international).
  Future<Result<WalletOverview>> transfer({required String recipientPhone, required int amount, String? note});
}

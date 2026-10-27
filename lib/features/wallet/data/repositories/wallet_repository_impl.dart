import '../../../../core/data/repository_guard.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/wallet_data_sources.dart';

class WalletRepositoryImpl implements WalletRepository {
  const WalletRepositoryImpl(this._remote);
  final WalletRemoteDataSource _remote;

  @override
  Future<Result<WalletOverview>> getOverview() => guard(_remote.overview);

  @override
  Future<Result<List<TopUpSource>>> getTopUpSources() => guard(_remote.sources);

  @override
  Future<Result<List<Beneficiary>>> getBeneficiaries() => guard(_remote.beneficiaries);

  @override
  Future<Result<WalletOverview>> topUp({required int amount, required String phone}) =>
      guard(() => _remote.topUp(amount, phone));

  @override
  Future<Result<WalletOverview>> transfer({required String recipientPhone, required int amount, String? note}) =>
      guard(() => _remote.transfer(recipientPhone, amount, note));
}

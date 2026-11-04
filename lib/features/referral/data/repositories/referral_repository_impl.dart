import '../../../../core/data/repository_guard.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/referral.dart';
import '../../domain/repositories/referral_repository.dart';
import '../datasources/referral_data_sources.dart';

class ReferralRepositoryImpl implements ReferralRepository {
  const ReferralRepositoryImpl(this._remote);
  final ReferralRemoteDataSource _remote;

  @override
  Future<Result<ReferralOverview>> getOverview() => guard(_remote.overview);

  @override
  Future<Result<IncomingReferral>> applyCode(String code) => guard(() => _remote.apply(code));
}

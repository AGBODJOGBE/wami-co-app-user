import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/referral.dart';
import '../repositories/referral_repository.dart';

class GetReferralOverview implements UseCase<ReferralOverview, NoParams> {
  const GetReferralOverview(this._repo);
  final ReferralRepository _repo;

  @override
  Future<Result<ReferralOverview>> call(NoParams _) => _repo.getOverview();
}

class ApplyReferralCode implements UseCase<IncomingReferral, String> {
  const ApplyReferralCode(this._repo);
  final ReferralRepository _repo;

  @override
  Future<Result<IncomingReferral>> call(String code) {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return Future.value(const Err(ValidationFailure('Saisissez le code de votre proche.')));
    return _repo.applyCode(clean);
  }
}

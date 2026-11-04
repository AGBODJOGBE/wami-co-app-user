import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/app_version_status.dart';
import '../repositories/app_update_repository.dart';

class CheckAppVersion implements UseCase<AppVersionStatus, NoParams> {
  const CheckAppVersion(this._repo);
  final AppUpdateRepository _repo;

  @override
  Future<Result<AppVersionStatus>> call(NoParams _) => _repo.check();
}

import '../../../../core/utils/result.dart';
import '../entities/app_version_status.dart';

abstract interface class AppUpdateRepository {
  Future<Result<AppVersionStatus>> check();
}

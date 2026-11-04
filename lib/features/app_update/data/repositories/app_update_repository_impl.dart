import '../../../../core/data/repository_guard.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/app_version_status.dart';
import '../../domain/repositories/app_update_repository.dart';
import '../datasources/app_update_data_sources.dart';

class AppUpdateRepositoryImpl implements AppUpdateRepository {
  const AppUpdateRepositoryImpl(this._remote);
  final AppUpdateRemoteDataSource _remote;

  @override
  Future<Result<AppVersionStatus>> check() => guard(_remote.check);
}

import '../../../../core/data/repository_guard.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/account_data_sources.dart';

class AccountRepositoryImpl implements AccountRepository {
  const AccountRepositoryImpl(this._remote, this._local);
  final AccountRemoteDataSource _remote;
  final SettingsLocalDataSource _local;

  @override
  Future<Result<UserProfile>> getProfile() => guard(_remote.profile);

  @override
  Future<Result<UserProfile>> updateProfile(UserProfile profile) => guard(() => _remote.updateProfile(profile));

  @override
  Future<Result<AppSettings>> getSettings() => guard(_local.read);

  @override
  Future<Result<void>> saveSettings(AppSettings settings) => guard(() => _local.write(settings));

  @override
  Future<Result<List<FaqItem>>> getFaq() => guard(_remote.faq);

  @override
  Future<Result<void>> requestDataExport() => guard(_remote.requestDataExport);
}

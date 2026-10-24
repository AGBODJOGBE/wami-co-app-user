import '../../../../core/utils/result.dart';
import '../entities/app_settings.dart';
import '../entities/user_profile.dart';

abstract interface class AccountRepository {
  Future<Result<UserProfile>> getProfile();
  Future<Result<UserProfile>> updateProfile(UserProfile profile);
  Future<Result<AppSettings>> getSettings();
  Future<Result<void>> saveSettings(AppSettings settings);
  Future<Result<List<FaqItem>>> getFaq();
  Future<Result<void>> requestDataExport();
}

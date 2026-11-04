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

  /// Le mot de passe actuel est exigé par le back.
  Future<Result<void>> changePassword({required String currentPassword, required String newPassword});

  /// Supprime le compte après confirmation par le mot de passe. La session se termine ensuite.
  Future<Result<void>> deleteAccount(String password);
}

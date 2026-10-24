import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/app_settings.dart';
import '../entities/user_profile.dart';
import '../repositories/account_repository.dart';

class GetProfile implements UseCase<UserProfile, NoParams> {
  const GetProfile(this._repo);
  final AccountRepository _repo;

  @override
  Future<Result<UserProfile>> call(NoParams _) => _repo.getProfile();
}

class UpdateProfile implements UseCase<UserProfile, UserProfile> {
  const UpdateProfile(this._repo);
  final AccountRepository _repo;

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  Future<Result<UserProfile>> call(UserProfile p) async {
    if (p.fullName.trim().length < 2) return const Err(ValidationFailure('Indiquez votre nom complet.'));
    if (p.email.isNotEmpty && !_email.hasMatch(p.email)) {
      return const Err(ValidationFailure('Adresse e-mail invalide.'));
    }
    return _repo.updateProfile(p);
  }
}

class GetSettings implements UseCase<AppSettings, NoParams> {
  const GetSettings(this._repo);
  final AccountRepository _repo;

  @override
  Future<Result<AppSettings>> call(NoParams _) => _repo.getSettings();
}

class SaveSettings implements UseCase<void, AppSettings> {
  const SaveSettings(this._repo);
  final AccountRepository _repo;

  @override
  Future<Result<void>> call(AppSettings s) => _repo.saveSettings(s);
}

class GetFaq implements UseCase<List<FaqItem>, NoParams> {
  const GetFaq(this._repo);
  final AccountRepository _repo;

  @override
  Future<Result<List<FaqItem>>> call(NoParams _) => _repo.getFaq();
}

class RequestDataExport implements UseCase<void, NoParams> {
  const RequestDataExport(this._repo);
  final AccountRepository _repo;

  @override
  Future<Result<void>> call(NoParams _) => _repo.requestDataExport();
}

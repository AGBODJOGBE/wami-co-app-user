import '../../../../core/auth/auth_session.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/password_policy.dart';
import '../../../../core/utils/result.dart';
import '../entities/auth_entities.dart';
import '../repositories/auth_repository.dart';

class SendOtp implements UseCase<void, String> {
  const SendOtp(this._repo);
  final AuthRepository _repo;

  @override
  Future<Result<void>> call(String phone) => _repo.sendOtp(phone);
}

class VerifyOtpParams {
  const VerifyOtpParams({required this.phone, required this.code});
  final String phone;
  final String code;
}

class VerifyOtp implements UseCase<PhoneCheck, VerifyOtpParams> {
  const VerifyOtp(this._repo);
  final AuthRepository _repo;

  @override
  Future<Result<PhoneCheck>> call(VerifyOtpParams p) {
    if (!RegExp(r'^\d{4,8}$').hasMatch(p.code)) {
      return Future.value(const Err(ValidationFailure('Saisissez le code reçu par SMS.')));
    }
    return _repo.verifyOtp(p.phone, p.code);
  }
}

class RequestPasswordReset implements UseCase<void, String> {
  const RequestPasswordReset(this._repo);
  final AuthRepository _repo;

  @override
  Future<Result<void>> call(String phone) => _repo.requestPasswordReset(phone);
}

class ResetPasswordParams {
  const ResetPasswordParams({required this.phone, required this.code, required this.newPassword});
  final String phone;
  final String code;
  final String newPassword;
}

class ResetPassword implements UseCase<void, ResetPasswordParams> {
  const ResetPassword(this._repo);
  final AuthRepository _repo;

  @override
  Future<Result<void>> call(ResetPasswordParams p) async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(p.code)) {
      return const Err(ValidationFailure('Saisissez le code reçu par SMS.'));
    }
    final weak = PasswordPolicy.check(p.newPassword);
    if (weak != null) return Err(ValidationFailure(weak));
    return _repo.resetPassword(phone: p.phone, code: p.code, newPassword: p.newPassword);
  }
}

class LoginParams {
  const LoginParams({required this.phone, required this.password});
  final String phone;
  final String password;
}

class LoginPassenger implements UseCase<AuthSession, LoginParams> {
  const LoginPassenger(this._repo);
  final AuthRepository _repo;

  @override
  Future<Result<AuthSession>> call(LoginParams p) {
    if (p.password.isEmpty) return Future.value(const Err(ValidationFailure('Saisissez votre mot de passe.')));
    return _repo.login(p.phone, p.password);
  }
}

/// Crée le compte puis ouvre la session avec les mêmes identifiants.
class RegisterPassenger implements UseCase<AuthSession, RegisterData> {
  const RegisterPassenger(this._repo);
  final AuthRepository _repo;

  @override
  Future<Result<AuthSession>> call(RegisterData d) async {
    final weak = PasswordPolicy.check(d.password);
    if (weak != null) return Err(ValidationFailure(weak));
    if (d.firstName.trim().isEmpty || d.lastName.trim().isEmpty) {
      return const Err(ValidationFailure('Indiquez votre nom et votre prénom.'));
    }
    final created = await _repo.register(d);
    return switch (created) {
      Err(:final failure) => Err(failure),
      Ok() => _repo.login(d.phone, d.password),
    };
  }
}

class RestoreSession {
  const RestoreSession(this._repo);
  final AuthRepository _repo;

  Future<AuthSession?> call() => _repo.restore();
}

class SignOut {
  const SignOut(this._repo);
  final AuthRepository _repo;

  Future<void> call() => _repo.signOut();
}

import '../../../../core/auth/auth_session.dart';
import '../../../../core/utils/result.dart';
import '../entities/auth_entities.dart';

abstract interface class AuthRepository {
  Future<Result<void>> sendOtp(String phone);
  Future<Result<PhoneCheck>> verifyOtp(String phone, String code);
  Future<Result<void>> register(RegisterData data);

  /// Ouvre la session et la range dans le stockage sécurisé.
  Future<Result<AuthSession>> login(String phone, String password);

  /// Session conservée par l'appareil, s'il y en a une.
  Future<AuthSession?> restore();
  Future<void> signOut();
}

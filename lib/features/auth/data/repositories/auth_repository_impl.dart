import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/session_store.dart';
import '../../../../core/data/repository_guard.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/auth_entities.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_data_sources.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remote, this._store);
  final AuthRemoteDataSource _remote;
  final SessionStore _store;

  @override
  Future<Result<void>> sendOtp(String phone) => guard(() => _remote.sendOtp(phone));

  @override
  Future<Result<PhoneCheck>> verifyOtp(String phone, String code) => guard(() => _remote.verifyOtp(phone, code));

  @override
  Future<Result<void>> register(RegisterData data) => guard(() => _remote.register(data));

  @override
  Future<Result<AuthSession>> login(String phone, String password) async {
    final result = await guard(() => _remote.login(phone, password));
    switch (result) {
      case Ok(:final value):
        await _store.write(value);
        return result;
      // Le serveur répond 401 ou 404 selon le cas : pour l'utilisateur, c'est la même chose.
      case Err(failure: UnauthorizedFailure() || ValidationFailure()):
        return const Err(UnauthorizedFailure('Numéro ou mot de passe incorrect.'));
      case Err():
        return result;
    }
  }

  @override
  Future<AuthSession?> restore() => _store.read();

  @override
  Future<void> signOut() => _store.clear();
}

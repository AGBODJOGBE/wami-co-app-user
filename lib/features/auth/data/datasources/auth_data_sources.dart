import '../../../../core/auth/auth_session.dart';
import '../../../../core/data/fake_backend.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/auth_entities.dart';

abstract interface class AuthRemoteDataSource {
  Future<void> sendOtp(String phone);
  Future<PhoneCheck> verifyOtp(String phone, String code);
  Future<void> register(RegisterData data);
  Future<AuthSession> login(String phone, String password);
}

/// Routes `/api/passengers/*` du back wami-co.
class AuthApiDataSource implements AuthRemoteDataSource {
  const AuthApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<void> sendOtp(String phone) async {
    await _api.post('/api/passengers/send-otp', body: {'phoneNumber': phone});
  }

  @override
  Future<PhoneCheck> verifyOtp(String phone, String code) async {
    final json = await _api.post('/api/passengers/verify-otp', body: {'phoneNumber': phone, 'code': code});
    return PhoneCheck(hasPassengerAccount: json['hasAccount'] == true);
  }

  @override
  Future<void> register(RegisterData d) async {
    await _api.post(
      '/api/passengers/register',
      body: {
        'phoneNumber': d.phone,
        'firstName': d.firstName.trim(),
        'lastName': d.lastName.trim(),
        'password': d.password,
        'gender': d.gender == Gender.male ? 'MALE' : 'FEMALE',
        if (d.email != null && d.email!.trim().isNotEmpty) 'email': d.email!.trim(),
        if (d.referralCode != null && d.referralCode!.trim().isNotEmpty) 'usedReferralCode': d.referralCode!.trim(),
      },
    );
  }

  @override
  Future<AuthSession> login(String phone, String password) async {
    final json = await _api.post('/api/passengers/login', body: {'phoneNumber': phone, 'password': password});
    final user = json['user'] as Map<String, dynamic>;
    return AuthSession(
      token: json['token'] as String,
      userId: user['userId'] as String,
      passengerId: user['passengerId'] as String,
      walletId: user['walletId'] as String,
      phone: user['phoneNumber'] as String,
      firstName: user['firstName'] as String? ?? '',
      lastName: user['lastName'] as String? ?? '',
      email: user['email'] as String?,
    );
  }
}

/// Simulation : le code est toujours `123456`.
class AuthFakeDataSource implements AuthRemoteDataSource {
  AuthFakeDataSource(this._fake);
  final FakeBackend _fake;

  static const validCode = '123456';
  final _accounts = <String, RegisterData>{};

  @override
  Future<void> sendOtp(String phone) => _fake.latency();

  @override
  Future<PhoneCheck> verifyOtp(String phone, String code) async {
    await _fake.latency();
    if (code != validCode) throw const BusinessRuleException('invalid_otp', 'Code incorrect ou expiré.');
    return PhoneCheck(hasPassengerAccount: _accounts.containsKey(phone));
  }

  @override
  Future<void> register(RegisterData data) async {
    await _fake.latency();
    _accounts[data.phone] = data;
  }

  @override
  Future<AuthSession> login(String phone, String password) async {
    await _fake.latency();
    final account = _accounts[phone];
    if (account == null || account.password != password) throw const UnauthorizedException();
    return AuthSession(
      token: 'fake-token',
      userId: 'fake-user',
      passengerId: 'fake-passenger',
      walletId: 'fake-wallet',
      phone: phone,
      firstName: account.firstName,
      lastName: account.lastName,
      email: account.email,
    );
  }
}

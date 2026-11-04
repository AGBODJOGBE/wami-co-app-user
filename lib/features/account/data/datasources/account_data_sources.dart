import '../../../../core/auth/current_session.dart';
import '../../../../core/data/fake_backend.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/phone.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/user_profile.dart';

abstract interface class AccountRemoteDataSource {
  Future<UserProfile> profile();
  Future<UserProfile> updateProfile(UserProfile p);
  Future<List<FaqItem>> faq();
  Future<void> requestDataExport();
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<void> deleteAccount(String password);
  Future<UserProfile> setGender(Gender gender);
  Future<UserProfile> setAddress(PostalAddress address);
  Future<void> resendVerification();
  Future<UserProfile> verify(VerificationKind kind, String code);
}

/// Préférences locales à l'appareil.
/// En production : shared_preferences (à ajouter) — ici en mémoire.
abstract interface class SettingsLocalDataSource {
  Future<AppSettings> read();
  Future<void> write(AppSettings settings);
}

class InMemorySettingsDataSource implements SettingsLocalDataSource {
  AppSettings _settings = const AppSettings();

  @override
  Future<AppSettings> read() async => _settings;

  @override
  Future<void> write(AppSettings settings) async {
    _settings = settings;
  }
}

/// Questions fréquentes : contenu du mobile (le back n'en a pas).
const _faqItems = [
  FaqItem(
    question: 'Comment est calculé le temps d’attente ?',
    answer:
        'Les premières minutes après l’arrivée du chauffeur sont gratuites, puis chaque minute entamée est facturée. Durée gratuite et tarif : [à valider].',
  ),
  FaqItem(
    question: 'Le chauffeur a fait une pause, est-ce facturé ?',
    answer: 'La pause s’affiche en direct pendant la course. Règle de facturation de la pause : [à valider].',
  ),
  FaqItem(
    question: 'Comment annuler un billet de bus ?',
    answer: 'Depuis Activités, ouvrez le billet puis « Annuler ». Remboursement selon la compagnie : [à valider].',
  ),
  FaqItem(
    question: 'Mon colis n’est pas arrivé',
    answer:
        'Ouvrez le suivi depuis Activités et contactez le coursier, ou écrivez au support avec la référence de l’envoi.',
  ),
];

/// Identité du passager sur le back wami-co. Le reste du profil du mobile (niveau, lieux, contact d'urgence)
/// n'existe pas côté back : il est gardé en mémoire de l'application (voir docs/BACKEND_A_FAIRE.md).
class AccountApiDataSource implements AccountRemoteDataSource {
  AccountApiDataSource(this._api, this._session);
  final ApiClient _api;
  final CurrentSession _session;

  // Pas de stockage côté back : perdus au redémarrage de l'application.
  List<SavedPlace> _savedPlaces = const [];
  String? _emergencyContact;

  // Le profil du back ne renvoie ni l'e-mail ni l'adresse : on garde ce qui a été saisi pendant la session.
  String? _email;
  PostalAddress? _address;

  String get _userId => _session.value!.userId;

  @override
  Future<UserProfile> profile() async {
    final j = await _api.get('/api/passengers/profile');
    return UserProfile(
      fullName: '${j['firstName'] ?? ''} ${j['lastName'] ?? ''}'.trim(),
      phone: j['phoneNumber'] as String? ?? '',
      email: j['email'] as String? ?? _email ?? '',
      // Pas de programme de fidélité ni de note passager côté back : rien n'est affiché.
      tier: '',
      rating: 0,
      savedPlaces: _savedPlaces,
      emergencyContact: _emergencyContact,
      gender: Gender.fromApi(j['gender'] as String?),
      address: _addressOf(j['address']) ?? _address,
      emailVerified: j['isEmailVerified'] as bool? ?? false,
      phoneVerified: j['isPhoneVerified'] as bool? ?? true,
    );
  }

  static PostalAddress? _addressOf(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final city = raw['city'] as String?;
    final quarter = raw['quarter'] as String?;
    if (city == null || quarter == null) return null;
    return PostalAddress(
      city: city,
      quarter: quarter,
      street: raw['street'] as String?,
      landmark: raw['landmark'] as String?,
    );
  }

  @override
  Future<UserProfile> updateProfile(UserProfile p) async {
    final current = await profile();
    if (p.fullName.trim() != current.fullName) {
      final parts = p.fullName.trim().split(RegExp(r'\s+'));
      await _api.patch(
        '/api/users/$_userId/name',
        body: {'firstName': parts.first, 'lastName': parts.length > 1 ? parts.skip(1).join(' ') : parts.first},
      );
    }
    final email = p.email.trim();
    if (email.isNotEmpty && email != current.email) {
      await _saveEmail(email, hadEmail: current.email.isNotEmpty);
      _email = email;
    }
    final phone = BeninPhone.toInternational(p.phone) ?? p.phone.trim();
    if (phone.isNotEmpty && phone != current.phone) {
      await _api.patch('/api/users/$_userId/phone', body: {'newPhoneNumber': phone});
    }
    _savedPlaces = p.savedPlaces;
    _emergencyContact = p.emergencyContact;
    return profile();
  }

  /// Ajout si le compte n'a pas encore d'e-mail, modification sinon. Le profil du back ne renvoie pas l'e-mail :
  /// quand on l'ignore, on tente l'ajout puis, si le back répond qu'il y en a déjà un, la modification.
  Future<void> _saveEmail(String email, {required bool hadEmail}) async {
    if (!hadEmail) {
      try {
        await _api.post('/api/users/$_userId/add-email', body: {'email': email});
        return;
      } on BusinessRuleException catch (e) {
        if (!(e.message ?? '').toLowerCase().contains('already has an email')) rethrow;
      }
    }
    await _api.patch('/api/users/$_userId/email', body: {'newEmail': email});
  }

  @override
  Future<UserProfile> setGender(Gender gender) async {
    await _api.patch('/api/users/$_userId/gender', body: {'gender': gender.api});
    return profile();
  }

  @override
  Future<UserProfile> setAddress(PostalAddress address) async {
    await _api.patch(
      '/api/users/$_userId/address',
      body: {
        'address': {
          'city': address.city.trim(),
          'quarter': address.quarter.trim(),
          if (address.street?.trim().isNotEmpty ?? false) 'street': address.street!.trim(),
          if (address.landmark?.trim().isNotEmpty ?? false) 'landmark': address.landmark!.trim(),
        },
      },
    );
    _address = address;
    return profile();
  }

  /// Le back renvoie les deux codes d'un coup (SMS et e-mail).
  @override
  Future<void> resendVerification() async {
    await _api.post('/api/users/$_userId/resend-verification', body: const <String, dynamic>{});
  }

  @override
  Future<UserProfile> verify(VerificationKind kind, String code) async {
    final route = kind == VerificationKind.email ? 'verify-email' : 'verify-phone';
    try {
      await _api.post('/api/users/$_userId/$route', body: {'code': code});
    } on BusinessRuleException catch (e) {
      throw _frenchVerifyError(e);
    }
    return profile();
  }

  BusinessRuleException _frenchVerifyError(BusinessRuleException e) {
    final m = (e.message ?? '').toLowerCase();
    if (m.contains('invalide') || m.contains('invalid') || m.contains('expir')) {
      return const BusinessRuleException('rejected', 'Code invalide ou expiré. Demandez un nouveau code.');
    }
    return e;
  }

  // Pas de FAQ ni d'export de données côté back : contenus du mobile.
  @override
  Future<List<FaqItem>> faq() async => _faqItems;

  @override
  Future<void> requestDataExport() async {}

  /// Un 401 ici veut dire « mot de passe actuel incorrect », pas « session expirée » : la session est conservée.
  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      await _api.put(
        '/api/passengers/password',
        body: {'currentPassword': currentPassword, 'newPassword': newPassword},
        keepSession: true,
      );
    } on UnauthorizedException {
      throw const BusinessRuleException('wrong_password', 'Mot de passe actuel incorrect.');
    }
  }

  @override
  Future<void> deleteAccount(String password) async {
    try {
      await _api.delete('/api/passengers/profile', body: {'password': password}, keepSession: true);
    } on UnauthorizedException {
      throw const BusinessRuleException('wrong_password', 'Mot de passe incorrect.');
    } on ServerException {
      // Le back supprime le profil puis plante (`user.deactivatePassengerProfile is not a function`) : il répond
      // 500 alors que le compte a disparu. On vérifie pour ne pas laisser croire à l'utilisateur qu'il existe encore.
      if (!await _accountIsGone()) rethrow;
    }
    // Le jeton est révoqué par le back : l'app revient à l'écran de connexion.
    _session.requestLogout();
  }

  Future<bool> _accountIsGone() async {
    try {
      await _api.get('/api/passengers/profile');
      return false;
    } on BusinessRuleException {
      return true; // 404 : profil introuvable.
    } on UnauthorizedException {
      return true; // jeton révoqué.
    } catch (_) {
      return false;
    }
  }
}

class AccountFakeDataSource implements AccountRemoteDataSource {
  AccountFakeDataSource(this._fake, this._session);
  final FakeBackend _fake;
  final CurrentSession _session;

  /// Les informations d'identité viennent de la session ; le reste (niveau, lieux, contact d'urgence) est simulé.
  late UserProfile _me = _initial();

  UserProfile _initial() {
    final s = _session.value;
    const base = _sample;
    if (s == null) return base;
    return UserProfile(
      fullName: s.fullName,
      phone: s.phone,
      email: s.email ?? '',
      tier: base.tier,
      rating: base.rating,
      savedPlaces: base.savedPlaces,
      emergencyContact: base.emergencyContact,
    );
  }

  static const _sample = UserProfile(
    fullName: 'Gilexe AGBODJOGBE',
    phone: '+229 [00 00 00 00]',
    email: '[adresse e-mail]',
    tier: 'Membre Or',
    rating: 4.9,
    savedPlaces: [
      SavedPlace(label: 'Maison', address: '[Quartier, Cotonou]'),
      SavedPlace(label: 'Travail', address: '[Quartier, Cotonou]'),
    ],
    emergencyContact: '[Nom du proche]',
  );

  @override
  Future<UserProfile> profile() async {
    await _fake.latency(0.5);
    return _me;
  }

  @override
  Future<UserProfile> updateProfile(UserProfile p) async {
    await _fake.latency();
    // Un nouvel e-mail est à vérifier à nouveau.
    return _me = _with(
      fullName: p.fullName,
      phone: p.phone,
      email: p.email,
      emailVerified: p.email == _me.email ? _me.emailVerified : false,
    );
  }

  @override
  Future<List<FaqItem>> faq() async {
    await _fake.latency(0.5);
    return _faqItems;
  }

  @override
  Future<void> requestDataExport() => _fake.latency();

  @override
  Future<void> changePassword(String currentPassword, String newPassword) => _fake.latency();

  @override
  Future<void> deleteAccount(String password) async {
    await _fake.latency();
    _session.requestLogout();
  }

  @override
  Future<UserProfile> setGender(Gender gender) async {
    await _fake.latency(0.4);
    return _me = _with(gender: gender);
  }

  @override
  Future<UserProfile> setAddress(PostalAddress address) async {
    await _fake.latency(0.4);
    return _me = _with(address: address);
  }

  @override
  Future<void> resendVerification() => _fake.latency(0.4);

  /// Code de démonstration : 123456.
  @override
  Future<UserProfile> verify(VerificationKind kind, String code) async {
    await _fake.latency(0.4);
    if (code != '123456') {
      throw const BusinessRuleException('rejected', 'Code invalide ou expiré. Demandez un nouveau code.');
    }
    return _me = _with(
      emailVerified: kind == VerificationKind.email ? true : null,
      phoneVerified: kind == VerificationKind.phone ? true : null,
    );
  }

  UserProfile _with({
    String? fullName,
    String? phone,
    String? email,
    Gender? gender,
    PostalAddress? address,
    bool? emailVerified,
    bool? phoneVerified,
  }) =>
      UserProfile(
        fullName: fullName ?? _me.fullName,
        phone: phone ?? _me.phone,
        email: email ?? _me.email,
        tier: _me.tier,
        rating: _me.rating,
        savedPlaces: _me.savedPlaces,
        emergencyContact: _me.emergencyContact,
        gender: gender ?? _me.gender,
        address: address ?? _me.address,
        emailVerified: emailVerified ?? _me.emailVerified,
        phoneVerified: phoneVerified ?? _me.phoneVerified,
      );
}

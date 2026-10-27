import '../../../../core/auth/current_session.dart';
import '../../../../core/data/fake_backend.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/phone.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/user_profile.dart';

abstract interface class AccountRemoteDataSource {
  Future<UserProfile> profile();
  Future<UserProfile> updateProfile(UserProfile p);
  Future<List<FaqItem>> faq();
  Future<void> requestDataExport();
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

  String get _userId => _session.value!.userId;

  @override
  Future<UserProfile> profile() async {
    final j = await _api.get('/api/passengers/profile');
    return UserProfile(
      fullName: '${j['firstName'] ?? ''} ${j['lastName'] ?? ''}'.trim(),
      phone: j['phoneNumber'] as String? ?? '',
      email: j['email'] as String? ?? '',
      // Pas de programme de fidélité ni de note passager côté back : rien n'est affiché.
      tier: '',
      rating: 0,
      savedPlaces: _savedPlaces,
      emergencyContact: _emergencyContact,
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
      await _api.patch('/api/users/$_userId/email', body: {'newEmail': email});
    }
    final phone = BeninPhone.toInternational(p.phone) ?? p.phone.trim();
    if (phone.isNotEmpty && phone != current.phone) {
      await _api.patch('/api/users/$_userId/phone', body: {'newPhoneNumber': phone});
    }
    _savedPlaces = p.savedPlaces;
    _emergencyContact = p.emergencyContact;
    return profile();
  }

  // Pas de FAQ ni d'export de données côté back : contenus du mobile.
  @override
  Future<List<FaqItem>> faq() async => _faqItems;

  @override
  Future<void> requestDataExport() async {}
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
    return _me = p;
  }

  @override
  Future<List<FaqItem>> faq() async {
    await _fake.latency(0.5);
    return _faqItems;
  }

  @override
  Future<void> requestDataExport() => _fake.latency();
}

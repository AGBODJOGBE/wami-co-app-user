import '../../../../core/auth/current_session.dart';
import '../../../../core/data/fake_backend.dart';
import '../../../../core/network/api_client.dart';
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

UserProfile _profile(Map<String, dynamic> j) => UserProfile(
      fullName: j['full_name'] as String,
      phone: j['phone'] as String,
      email: j['email'] as String? ?? '',
      tier: j['tier'] as String? ?? '',
      rating: (j['rating'] as num? ?? 5).toDouble(),
      savedPlaces: (j['saved_places'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map((p) => SavedPlace(label: p['label'] as String, address: p['address'] as String))
          .toList(),
      emergencyContact: j['emergency_contact'] as String?,
    );

/// Endpoints à valider.
class AccountApiDataSource implements AccountRemoteDataSource {
  const AccountApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<UserProfile> profile() async => _profile(await _api.get('/v1/me'));

  @override
  Future<UserProfile> updateProfile(UserProfile p) async =>
      _profile(await _api.put('/v1/me', body: {'full_name': p.fullName, 'phone': p.phone, 'email': p.email}));

  @override
  Future<List<FaqItem>> faq() async => ((await _api.get('/v1/support/faq'))['items'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .map((f) => FaqItem(question: f['question'] as String, answer: f['answer'] as String))
      .toList();

  @override
  Future<void> requestDataExport() => _api.post('/v1/me/data-export');
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
    return const [
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
  }

  @override
  Future<void> requestDataExport() => _fake.latency();
}

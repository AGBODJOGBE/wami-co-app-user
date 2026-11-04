/// Configuration d'exécution, lue depuis les `--dart-define`.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.useFakeBackend,
    this.geocoderUrl = 'https://nominatim.openstreetmap.org',
    this.checkVersion,
    this.fakeLatency = const Duration(milliseconds: 450),
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      apiBaseUrl: String.fromEnvironment(
        'WAMI_API_URL',
        // À valider : URL de l'API WAMI.
        defaultValue: 'https://api.wami.example',
      ),
      useFakeBackend: bool.fromEnvironment('WAMI_FAKE_BACKEND', defaultValue: true),
      geocoderUrl: String.fromEnvironment('WAMI_GEOCODER_URL', defaultValue: 'https://nominatim.openstreetmap.org'),
      // Vide : par défaut, vérifié seulement avec le vrai back.
      checkVersion: String.fromEnvironment('WAMI_CHECK_VERSION') == ''
          ? null
          : String.fromEnvironment('WAMI_CHECK_VERSION') == 'true',
    );
  }

  /// Adresse de base des API REST.
  final String apiBaseUrl;

  /// Adresse du serveur sans `/api` final : les routes de l'app commencent déjà par `/api`,
  /// donc `http://10.0.2.2:3000/api` et `http://10.0.2.2:3000` donnent le même résultat.
  String get serverUrl => apiBaseUrl.replaceFirst(RegExp(r'/+$'), '').replaceFirst(RegExp(r'/api$'), '');

  /// `true` : les sources de données simulées remplacent les appels HTTP.
  final bool useFakeBackend;

  /// Service de recherche d'adresses (à remplacer en production, voir `NominatimGeocoder`).
  final String geocoderUrl;

  /// Vérifier au démarrage que l'application est à jour. `null` : oui avec le vrai back, non avec le faux backend.
  /// Le back refuse les versions inférieures à sa version minimale : `--dart-define=WAMI_CHECK_VERSION=false`
  /// permet de développer avec une version de test.
  final bool? checkVersion;

  bool get shouldCheckVersion => checkVersion ?? !useFakeBackend;

  /// Délai artificiel des sources simulées, pour voir les états de chargement.
  final Duration fakeLatency;
}

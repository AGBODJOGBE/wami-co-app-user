/// Configuration d'exécution, lue depuis les `--dart-define`.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.useFakeBackend,
    this.geocoderUrl = 'https://nominatim.openstreetmap.org',
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
    );
  }

  /// Adresse de base des API REST.
  final String apiBaseUrl;

  /// `true` : les sources de données simulées remplacent les appels HTTP.
  final bool useFakeBackend;

  /// Service de recherche d'adresses (à remplacer en production, voir `NominatimGeocoder`).
  final String geocoderUrl;

  /// Délai artificiel des sources simulées, pour voir les états de chargement.
  final Duration fakeLatency;
}

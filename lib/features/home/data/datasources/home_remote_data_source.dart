import '../../../../core/auth/current_session.dart';
import '../../../../core/data/fake_backend.dart';
import '../../../../core/domain/service_type.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/home_feed.dart';
import '../models/home_feed_model.dart';

abstract interface class HomeRemoteDataSource {
  Future<HomeFeed> fetchFeed();
}

/// Implémentation HTTP. Endpoint à valider.
class HomeApiDataSource implements HomeRemoteDataSource {
  const HomeApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<HomeFeed> fetchFeed() async => HomeFeedModel.fromJson(await _api.get('/v1/home/feed'));
}

/// Données simulées pour développer sans backend.
class HomeFakeDataSource implements HomeRemoteDataSource {
  const HomeFakeDataSource(this._fake, this._session);
  final FakeBackend _fake;
  final CurrentSession _session;

  @override
  Future<HomeFeed> fetchFeed() async {
    await _fake.latency();
    return HomeFeed(
      firstName: _session.value?.firstName ?? 'Gilexe',
      promos: [
        const PromoBanner(
          id: 'p1',
          title: '−20 % sur votre 1re course Confort',
          subtitle: 'Code de bienvenue [à valider]',
          ctaLabel: 'J’en profite',
          service: ServiceType.mobility,
        ),
        const PromoBanner(
          id: 'p2',
          title: 'Cotonou → Parakou dès [prix]',
          subtitle: 'Comparez les compagnies en un geste',
          ctaLabel: 'Voir les bus',
          service: ServiceType.bus,
        ),
        const PromoBanner(
          id: 'p3',
          title: 'Livraison express en moins d’1 h',
          subtitle: 'Partout en ville',
          ctaLabel: 'Envoyer un colis',
          service: ServiceType.delivery,
        ),
      ],
      quickDestinations: [
        const QuickDestination(id: 'q1', label: 'Maison', address: '[Quartier, Cotonou]', kind: QuickDestinationKind.home),
        const QuickDestination(id: 'q2', label: 'Travail', address: '[Quartier, Cotonou]', kind: QuickDestinationKind.work),
        const QuickDestination(id: 'q3', label: 'Aéroport', address: 'Cadjèhoun', kind: QuickDestinationKind.recent),
      ],
    );
  }
}

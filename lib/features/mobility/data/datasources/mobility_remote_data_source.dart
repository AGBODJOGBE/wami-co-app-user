import '../../../../core/network/api_client.dart';
import '../../domain/entities/place.dart';
import '../../domain/entities/ride.dart';
import '../../domain/entities/vehicle_offer.dart';
import '../../domain/entities/waiting_policy.dart';
import '../models/mobility_models.dart';

abstract interface class MobilityRemoteDataSource {
  Future<List<Place>> searchPlaces(String query);
  Future<List<VehicleOffer>> estimate(Place from, Place to);
  Future<WaitingPolicy> waitingPolicy();
  Future<String> requestRide(Place from, Place to, VehicleCategory category);
  Stream<RideSnapshot> watchRide(String rideId);
  Future<void> cancelRide(String rideId);
  Future<void> rateRide(RideRating rating);
}

/// Implémentation HTTP. Endpoints à valider avec l'équipe back.
class MobilityApiDataSource implements MobilityRemoteDataSource {
  const MobilityApiDataSource(this._api);
  final ApiClient _api;

  List<Map<String, dynamic>> _items(Map<String, dynamic> json) =>
      (json['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

  @override
  Future<List<Place>> searchPlaces(String query) async =>
      _items(await _api.get('/v1/places', query: {'q': query})).map(MobilityModels.place).toList();

  @override
  Future<List<VehicleOffer>> estimate(Place from, Place to) async {
    final json = await _api.post(
      '/v1/rides/estimate',
      body: {
        'from': MobilityModels.placeToJson(from),
        'to': MobilityModels.placeToJson(to),
      },
    );
    return _items(json).map(MobilityModels.offer).toList();
  }

  @override
  Future<WaitingPolicy> waitingPolicy() async => MobilityModels.policy(await _api.get('/v1/rides/waiting-policy'));

  @override
  Future<String> requestRide(Place from, Place to, VehicleCategory category) async {
    final json = await _api.post(
      '/v1/rides',
      body: {
        'from': MobilityModels.placeToJson(from),
        'to': MobilityModels.placeToJson(to),
        'category': category.name,
      },
    );
    return json['id'] as String;
  }

  /// Polling toutes les 3 s. À remplacer par un WebSocket (Socket.io) — à valider.
  @override
  Stream<RideSnapshot> watchRide(String rideId) async* {
    while (true) {
      final snap = MobilityModels.snapshot(await _api.get('/v1/rides/$rideId'));
      yield snap;
      if (snap.status == RideStatus.completed || snap.status == RideStatus.cancelled) return;
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  @override
  Future<void> cancelRide(String rideId) => _api.post('/v1/rides/$rideId/cancel');

  @override
  Future<void> rateRide(RideRating r) => _api.post(
        '/v1/rides/${r.rideId}/rating',
        body: {
          'stars': r.stars,
          'tags': r.tags.toList(),
          'tip': r.tip,
        },
      );
}

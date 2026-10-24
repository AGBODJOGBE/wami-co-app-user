import '../../../../core/utils/result.dart';
import '../entities/place.dart';
import '../entities/ride.dart';
import '../entities/vehicle_offer.dart';
import '../entities/waiting_policy.dart';

abstract interface class MobilityRepository {
  /// Position actuelle du téléphone, utilisée comme point de départ.
  Future<Result<Place>> currentPlace();

  Future<Result<List<Place>>> searchPlaces(String query);

  Future<Result<List<VehicleOffer>>> estimateOffers({required Place from, required Place to});

  Future<Result<WaitingPolicy>> getWaitingPolicy();

  /// Renvoie l'identifiant de la course créée.
  Future<Result<String>> requestRide({
    required Place from,
    required Place to,
    required VehicleCategory category,
  });

  /// Flux temps réel de la course (WebSocket ou polling côté data).
  Stream<RideSnapshot> watchRide(String rideId);

  Future<Result<void>> cancelRide(String rideId);

  Future<Result<void>> rateRide(RideRating rating);
}

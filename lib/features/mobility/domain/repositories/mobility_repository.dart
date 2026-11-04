import '../../../../core/utils/result.dart';
import '../entities/place.dart';
import '../entities/promo_usage.dart';
import '../entities/ride.dart';
import '../entities/vehicle_offer.dart';
import '../entities/waiting_policy.dart';

abstract interface class MobilityRepository {
  /// Position actuelle du téléphone, utilisée comme point de départ.
  Future<Result<Place>> currentPlace();

  Future<Result<List<Place>>> searchPlaces(String query);

  Future<Result<OfferQuote>> estimateOffers({required Place from, required Place to, String? promoCode});

  /// Codes promo que le passager peut utiliser.
  Future<Result<List<AvailablePromo>>> availablePromos();

  Future<Result<WaitingPolicy>> getWaitingPolicy();

  /// Renvoie l'identifiant de la course créée.
  Future<Result<String>> requestRide({
    required Place from,
    required Place to,
    required VehicleCategory category,
    String? promoCode,
  });

  /// Flux temps réel de la course (WebSocket ou polling côté data).
  Stream<RideSnapshot> watchRide(String rideId);

  Future<Result<void>> cancelRide(String rideId);

  Future<Result<void>> rateRide(RideRating rating);

  /// Demande au chauffeur de changer la destination pendant la course (il accepte ou refuse).
  Future<Result<void>> requestDestinationChange(String rideId, Place newDropoff);

  /// Part du portefeuille pour une course payée en mixte ; `null` = automatique.
  Future<Result<PaymentSplit>> setPaymentSplit(String rideId, int? walletAmount);

  Future<Result<PromoHistory>> promoHistory();
}

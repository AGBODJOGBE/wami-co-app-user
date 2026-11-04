import '../../../../core/data/repository_guard.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/place.dart';
import '../../domain/entities/ride.dart';
import '../../domain/entities/vehicle_offer.dart';
import '../../domain/entities/waiting_policy.dart';
import '../../domain/repositories/mobility_repository.dart';
import '../datasources/mobility_remote_data_source.dart';

class MobilityRepositoryImpl implements MobilityRepository {
  const MobilityRepositoryImpl(this._remote, this._location);
  final MobilityRemoteDataSource _remote;
  final LocationService _location;

  @override
  Future<Result<Place>> currentPlace() => guard(() async {
        final p = await _location.current();
        return Place(id: 'me', name: 'Ma position', address: 'Position actuelle', lat: p.lat, lng: p.lng);
      });

  @override
  Future<Result<List<Place>>> searchPlaces(String query) => guard(() => _remote.searchPlaces(query));

  @override
  Future<Result<OfferQuote>> estimateOffers({required Place from, required Place to, String? promoCode}) =>
      guard(() => _remote.estimate(from, to, promoCode: promoCode));

  @override
  Future<Result<List<AvailablePromo>>> availablePromos() => guard(_remote.availablePromos);

  @override
  Future<Result<WaitingPolicy>> getWaitingPolicy() => guard(_remote.waitingPolicy);

  @override
  Future<Result<String>> requestRide({
    required Place from,
    required Place to,
    required VehicleCategory category,
    String? promoCode,
  }) =>
      guard(() => _remote.requestRide(from, to, category, promoCode: promoCode));

  @override
  Stream<RideSnapshot> watchRide(String rideId) => _remote.watchRide(rideId);

  @override
  Future<Result<void>> cancelRide(String rideId) => guard(() => _remote.cancelRide(rideId));

  @override
  Future<Result<void>> rateRide(RideRating rating) => guard(() => _remote.rateRide(rating));
}

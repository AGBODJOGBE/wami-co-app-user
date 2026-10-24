import '../../../../core/data/repository_guard.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/place.dart';
import '../../domain/entities/ride.dart';
import '../../domain/entities/vehicle_offer.dart';
import '../../domain/entities/waiting_policy.dart';
import '../../domain/repositories/mobility_repository.dart';
import '../datasources/mobility_remote_data_source.dart';

class MobilityRepositoryImpl implements MobilityRepository {
  const MobilityRepositoryImpl(this._remote);
  final MobilityRemoteDataSource _remote;

  @override
  Future<Result<List<Place>>> searchPlaces(String query) => guard(() => _remote.searchPlaces(query));

  @override
  Future<Result<List<VehicleOffer>>> estimateOffers({required Place from, required Place to}) =>
      guard(() => _remote.estimate(from, to));

  @override
  Future<Result<WaitingPolicy>> getWaitingPolicy() => guard(_remote.waitingPolicy);

  @override
  Future<Result<String>> requestRide({
    required Place from,
    required Place to,
    required VehicleCategory category,
  }) =>
      guard(() => _remote.requestRide(from, to, category));

  @override
  Stream<RideSnapshot> watchRide(String rideId) => _remote.watchRide(rideId);

  @override
  Future<Result<void>> cancelRide(String rideId) => guard(() => _remote.cancelRide(rideId));

  @override
  Future<Result<void>> rateRide(RideRating rating) => guard(() => _remote.rateRide(rating));
}

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/place.dart';
import '../entities/ride.dart';
import '../entities/vehicle_offer.dart';
import '../entities/waiting_policy.dart';
import '../repositories/mobility_repository.dart';

class SearchPlaces implements UseCase<List<Place>, String> {
  const SearchPlaces(this._repo);
  final MobilityRepository _repo;

  @override
  Future<Result<List<Place>>> call(String query) async {
    if (query.trim().length < 2) return const Ok([]);
    return _repo.searchPlaces(query.trim());
  }
}

class RouteParams {
  const RouteParams({required this.from, required this.to});
  final Place from;
  final Place to;
}

/// Prix par gamme, triés du moins cher au plus cher, avec une recommandation.
class EstimateRideOffers implements UseCase<List<VehicleOffer>, RouteParams> {
  const EstimateRideOffers(this._repo);
  final MobilityRepository _repo;

  @override
  Future<Result<List<VehicleOffer>>> call(RouteParams p) async {
    if (p.from == p.to) {
      return const Err(ValidationFailure('Le départ et la destination sont identiques.'));
    }
    final result = await _repo.estimateOffers(from: p.from, to: p.to);
    return result.map((offers) => [...offers]..sort((a, b) => a.price.compareTo(b.price)));
  }
}

class GetWaitingPolicy implements UseCase<WaitingPolicy, NoParams> {
  const GetWaitingPolicy(this._repo);
  final MobilityRepository _repo;

  @override
  Future<Result<WaitingPolicy>> call(NoParams _) => _repo.getWaitingPolicy();
}

class RequestRideParams {
  const RequestRideParams({required this.from, required this.to, required this.category});
  final Place from;
  final Place to;
  final VehicleCategory category;
}

class RequestRide implements UseCase<String, RequestRideParams> {
  const RequestRide(this._repo);
  final MobilityRepository _repo;

  @override
  Future<Result<String>> call(RequestRideParams p) => _repo.requestRide(from: p.from, to: p.to, category: p.category);
}

class WatchRide implements StreamUseCase<RideSnapshot, String> {
  const WatchRide(this._repo);
  final MobilityRepository _repo;

  @override
  Stream<RideSnapshot> call(String rideId) => _repo.watchRide(rideId);
}

class CancelRide implements UseCase<void, String> {
  const CancelRide(this._repo);
  final MobilityRepository _repo;

  @override
  Future<Result<void>> call(String rideId) => _repo.cancelRide(rideId);
}

class RateRide implements UseCase<void, RideRating> {
  const RateRide(this._repo);
  final MobilityRepository _repo;

  @override
  Future<Result<void>> call(RideRating rating) async {
    if (rating.stars < 1 || rating.stars > 5) {
      return const Err(ValidationFailure('Choisissez une note entre 1 et 5.'));
    }
    return _repo.rateRide(rating);
  }
}

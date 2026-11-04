import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/place.dart';
import '../entities/ride.dart';
import '../entities/vehicle_offer.dart';
import '../entities/waiting_policy.dart';
import '../repositories/mobility_repository.dart';

class GetCurrentPlace implements UseCase<Place, NoParams> {
  const GetCurrentPlace(this._repo);
  final MobilityRepository _repo;

  @override
  Future<Result<Place>> call(NoParams _) => _repo.currentPlace();
}

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
  const RouteParams({required this.from, required this.to, this.promoCode});
  final Place from;
  final Place to;
  final String? promoCode;
}

/// Prix par gamme, triés du moins cher au plus cher, avec une recommandation.
class EstimateRideOffers implements UseCase<OfferQuote, RouteParams> {
  const EstimateRideOffers(this._repo);
  final MobilityRepository _repo;

  @override
  Future<Result<OfferQuote>> call(RouteParams p) async {
    if (p.from == p.to) {
      return const Err(ValidationFailure('Le départ et la destination sont identiques.'));
    }
    final code = p.promoCode?.trim().toUpperCase();
    final result = await _repo.estimateOffers(
      from: p.from,
      to: p.to,
      promoCode: code == null || code.isEmpty ? null : code,
    );
    return result.map(
      (quote) => OfferQuote(
        offers: [...quote.offers]..sort((a, b) => a.price.compareTo(b.price)),
        promoError: quote.promoError,
      ),
    );
  }
}

class GetAvailablePromos implements UseCase<List<AvailablePromo>, NoParams> {
  const GetAvailablePromos(this._repo);
  final MobilityRepository _repo;

  @override
  Future<Result<List<AvailablePromo>>> call(NoParams _) => _repo.availablePromos();
}

class GetWaitingPolicy implements UseCase<WaitingPolicy, NoParams> {
  const GetWaitingPolicy(this._repo);
  final MobilityRepository _repo;

  @override
  Future<Result<WaitingPolicy>> call(NoParams _) => _repo.getWaitingPolicy();
}

class RequestRideParams {
  const RequestRideParams({required this.from, required this.to, required this.category, this.promoCode});
  final Place from;
  final Place to;
  final VehicleCategory category;
  final String? promoCode;
}

class RequestRide implements UseCase<String, RequestRideParams> {
  const RequestRide(this._repo);
  final MobilityRepository _repo;

  @override
  Future<Result<String>> call(RequestRideParams p) =>
      _repo.requestRide(from: p.from, to: p.to, category: p.category, promoCode: p.promoCode);
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

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/bus.dart';
import '../repositories/bus_repository.dart';

class SearchBusTrips implements UseCase<List<BusTrip>, BusSearchQuery> {
  const SearchBusTrips(this._repo);
  final BusRepository _repo;

  @override
  Future<Result<List<BusTrip>>> call(BusSearchQuery q) async {
    if (q.from.trim().toLowerCase() == q.to.trim().toLowerCase()) {
      return const Err(ValidationFailure('Choisissez deux villes différentes.'));
    }
    final result = await _repo.searchTrips(q);
    // On ne propose que les départs qui ont assez de places pour tout le groupe.
    return result.map((trips) => trips.where((t) => t.seatsLeft >= q.passengers).toList());
  }
}

class GetSeatMap implements UseCase<SeatMap, String> {
  const GetSeatMap(this._repo);
  final BusRepository _repo;

  @override
  Future<Result<SeatMap>> call(String tripId) => _repo.getSeatMap(tripId);
}

class BookSeatsParams {
  const BookSeatsParams({required this.trip, required this.query, required this.seats});
  final BusTrip trip;
  final BusSearchQuery query;
  final List<String> seats;
}

class BookBusSeats implements UseCase<BusTicket, BookSeatsParams> {
  const BookBusSeats(this._repo);
  final BusRepository _repo;

  @override
  Future<Result<BusTicket>> call(BookSeatsParams p) async {
    if (p.seats.length != p.query.passengers) {
      return Err(ValidationFailure('Choisissez ${p.query.passengers} siège(s).'));
    }
    return _repo.book(trip: p.trip, query: p.query, seats: p.seats);
  }
}

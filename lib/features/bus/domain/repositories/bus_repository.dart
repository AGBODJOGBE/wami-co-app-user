import '../../../../core/utils/result.dart';
import '../entities/bus.dart';

abstract interface class BusRepository {
  Future<Result<List<BusTrip>>> searchTrips(BusSearchQuery query);
  Future<Result<SeatMap>> getSeatMap(String tripId);
  Future<Result<BusTicket>> book({required BusTrip trip, required BusSearchQuery query, required List<String> seats});
}

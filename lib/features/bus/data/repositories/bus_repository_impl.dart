import '../../../../core/data/repository_guard.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/bus.dart';
import '../../domain/repositories/bus_repository.dart';
import '../datasources/bus_data_sources.dart';

class BusRepositoryImpl implements BusRepository {
  const BusRepositoryImpl(this._remote);
  final BusRemoteDataSource _remote;

  @override
  Future<Result<List<BusTrip>>> searchTrips(BusSearchQuery query) => guard(() => _remote.search(query));

  @override
  Future<Result<SeatMap>> getSeatMap(String tripId) => guard(() => _remote.seatMap(tripId));

  @override
  Future<Result<BusTicket>> book({required BusTrip trip, required BusSearchQuery query, required List<String> seats}) =>
      guard(() => _remote.book(trip, query, seats));
}

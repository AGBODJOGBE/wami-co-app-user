import '../../../../core/data/repository_guard.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/lodging.dart';
import '../../domain/repositories/lodging_repository.dart';
import '../datasources/lodging_data_sources.dart';

class LodgingRepositoryImpl implements LodgingRepository {
  const LodgingRepositoryImpl(this._remote);
  final LodgingRemoteDataSource _remote;

  @override
  Future<Result<List<Lodging>>> search(StaySearch search) => guard(() => _remote.search(search));

  @override
  Future<Result<List<RoomOption>>> getRooms(String lodgingId) => guard(() => _remote.rooms(lodgingId));

  @override
  Future<Result<Booking>> book({
    required Lodging lodging,
    required RoomOption room,
    required StaySearch search,
    required PaymentMethod payment,
  }) =>
      guard(() => _remote.book(lodging, room, search, payment));

  @override
  Future<Result<List<VisitSlot>>> getVisitSlots(String apartmentId) => guard(() => _remote.visitSlots(apartmentId));

  @override
  Future<Result<void>> requestVisit({required String apartmentId, required String slotId}) =>
      guard(() => _remote.requestVisit(apartmentId, slotId));
}

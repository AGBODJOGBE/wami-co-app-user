import '../../../../core/utils/result.dart';
import '../entities/lodging.dart';

abstract interface class LodgingRepository {
  Future<Result<List<Lodging>>> search(StaySearch search);
  Future<Result<List<RoomOption>>> getRooms(String lodgingId);
  Future<Result<Booking>> book({
    required Lodging lodging,
    required RoomOption room,
    required StaySearch search,
    required PaymentMethod payment,
  });
  Future<Result<List<VisitSlot>>> getVisitSlots(String apartmentId);
  Future<Result<void>> requestVisit({required String apartmentId, required String slotId});
}

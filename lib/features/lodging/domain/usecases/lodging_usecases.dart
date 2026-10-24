import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/lodging.dart';
import '../repositories/lodging_repository.dart';

/// Recherche « intelligente » : les établissements qui cochent le plus de
/// priorités de l'utilisateur remontent en tête, puis la note départage.
class SearchLodgings implements UseCase<List<Lodging>, StaySearch> {
  const SearchLodgings(this._repo);
  final LodgingRepository _repo;

  static int matchScore(Lodging l, Set<Amenity> priorities) => priorities.where(l.amenities.contains).length;

  @override
  Future<Result<List<Lodging>>> call(StaySearch s) async {
    final result = await _repo.search(s);
    return result.map((list) {
      final sorted = [...list];
      sorted.sort((a, b) {
        final byMatch = matchScore(b, s.priorities).compareTo(matchScore(a, s.priorities));
        return byMatch != 0 ? byMatch : b.rating.compareTo(a.rating);
      });
      return sorted;
    });
  }
}

class GetRooms implements UseCase<List<RoomOption>, String> {
  const GetRooms(this._repo);
  final LodgingRepository _repo;

  @override
  Future<Result<List<RoomOption>>> call(String id) => _repo.getRooms(id);
}

class BookStayParams {
  const BookStayParams({required this.lodging, required this.room, required this.search, required this.payment});
  final Lodging lodging;
  final RoomOption room;
  final StaySearch search;
  final PaymentMethod payment;
}

class BookStay implements UseCase<Booking, BookStayParams> {
  const BookStay(this._repo);
  final LodgingRepository _repo;

  @override
  Future<Result<Booking>> call(BookStayParams p) async {
    if (p.lodging.type.isMonthly) {
      return const Err(ValidationFailure('Un appartement se réserve après une visite.'));
    }
    return _repo.book(lodging: p.lodging, room: p.room, search: p.search, payment: p.payment);
  }
}

class GetVisitSlots implements UseCase<List<VisitSlot>, String> {
  const GetVisitSlots(this._repo);
  final LodgingRepository _repo;

  @override
  Future<Result<List<VisitSlot>>> call(String id) => _repo.getVisitSlots(id);
}

class RequestVisitParams {
  const RequestVisitParams({required this.apartmentId, required this.slot});
  final String apartmentId;
  final VisitSlot slot;
}

class RequestVisit implements UseCase<void, RequestVisitParams> {
  const RequestVisit(this._repo);
  final LodgingRepository _repo;

  @override
  Future<Result<void>> call(RequestVisitParams p) async {
    if (!p.slot.available) return const Err(UnavailableFailure('Ce créneau n’est plus libre.'));
    return _repo.requestVisit(apartmentId: p.apartmentId, slotId: p.slot.id);
  }
}

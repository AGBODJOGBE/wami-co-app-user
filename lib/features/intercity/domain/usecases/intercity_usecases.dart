import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/intercity.dart';
import '../repositories/intercity_repository.dart';

class SearchIntercityOffers implements UseCase<List<IntercityOffer>, IntercityQuery> {
  const SearchIntercityOffers(this._repo);
  final IntercityRepository _repo;

  @override
  Future<Result<List<IntercityOffer>>> call(IntercityQuery q) async {
    if (q.from.trim().isEmpty || q.to.trim().isEmpty) {
      return const Err(ValidationFailure('Choisissez la ville de départ et celle d’arrivée.'));
    }
    if (q.from.trim().toLowerCase() == q.to.trim().toLowerCase()) {
      return const Err(ValidationFailure('Choisissez deux villes différentes.'));
    }
    final today = DateTime.now();
    if (DateTime(q.date.year, q.date.month, q.date.day).isBefore(DateTime(today.year, today.month, today.day))) {
      return const Err(ValidationFailure('Cette date est déjà passée.'));
    }
    final result = await _repo.search(q);
    // Les plus tôt d'abord ; seulement ceux qui ont assez de places pour tout le groupe.
    return result.map(
      (offers) =>
          offers.where((o) => o.availableSeats >= q.seats).toList()..sort((a, b) => a.departure.compareTo(b.departure)),
    );
  }
}

class BookIntercityParams {
  const BookIntercityParams({required this.offer, required this.seats, required this.payment});
  final IntercityOffer offer;
  final int seats;
  final IntercityPayment payment;
}

class BookIntercityOffer implements UseCase<IntercityBooking, BookIntercityParams> {
  const BookIntercityOffer(this._repo);
  final IntercityRepository _repo;

  @override
  Future<Result<IntercityBooking>> call(BookIntercityParams p) async {
    if (p.offer.id == null) {
      return const Err(ValidationFailure('Ce trajet ne peut pas encore être réservé depuis l’application.'));
    }
    if (p.seats < 1) return const Err(ValidationFailure('Choisissez au moins une place.'));
    if (p.seats > p.offer.availableSeats) {
      return Err(ValidationFailure('Il ne reste que ${p.offer.availableSeats} place(s) sur ce trajet.'));
    }
    return _repo.book(offer: p.offer, seats: p.seats, payment: p.payment);
  }
}

class CancelIntercityBooking implements UseCase<int, String> {
  const CancelIntercityBooking(this._repo);
  final IntercityRepository _repo;

  @override
  Future<Result<int>> call(String bookingId) => _repo.cancel(bookingId);
}

import '../../../../core/utils/result.dart';
import '../entities/intercity.dart';

abstract interface class IntercityRepository {
  Future<Result<List<IntercityOffer>>> search(IntercityQuery query);

  Future<Result<IntercityBooking>> book({
    required IntercityOffer offer,
    required int seats,
    required IntercityPayment payment,
  });

  /// Annule la réservation et rend le montant remboursé (FCFA).
  Future<Result<int>> cancel(String bookingId);
}

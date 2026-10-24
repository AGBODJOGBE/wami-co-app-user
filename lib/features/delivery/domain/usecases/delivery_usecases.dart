import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/delivery.dart';
import '../repositories/delivery_repository.dart';

/// Vérifie que l'étape « adresses » est complète.
class ValidateDeliveryAddresses {
  const ValidateDeliveryAddresses();

  Failure? call(DeliveryDraft d) {
    if (d.dropoffAddress.trim().isEmpty && d.mode == DeliveryMode.send) {
      return const ValidationFailure('Indiquez l’adresse de livraison.');
    }
    if (d.pickupAddress.trim().isEmpty && d.mode == DeliveryMode.pickup) {
      return const ValidationFailure('Indiquez l’adresse de collecte.');
    }
    if (d.contactPhone.replaceAll(' ', '').length < 8) {
      return ValidationFailure('Numéro du ${d.contactRole.toLowerCase()} incomplet.');
    }
    return null;
  }
}

/// Devis par véhicule, le véhicule adapté à la taille du colis en premier.
class GetDeliveryQuotes implements UseCase<List<DeliveryQuote>, DeliveryDraft> {
  const GetDeliveryQuotes(this._repo);
  final DeliveryRepository _repo;

  @override
  Future<Result<List<DeliveryQuote>>> call(DeliveryDraft draft) async {
    final result = await _repo.getQuotes(draft);
    final best = DeliveryVehicle.recommendedFor(draft.size);
    return result.map(
      (quotes) => [
        for (final q in quotes)
          DeliveryQuote(vehicle: q.vehicle, price: q.price, etaMinutes: q.etaMinutes, suitable: q.vehicle == best),
      ]..sort((a, b) => (b.suitable ? 1 : 0) - (a.suitable ? 1 : 0)),
    );
  }
}

class PlaceDeliveryOrder implements UseCase<String, DeliveryDraft> {
  const PlaceDeliveryOrder(this._repo);
  final DeliveryRepository _repo;

  @override
  Future<Result<String>> call(DeliveryDraft draft) async {
    if (draft.cashOnDelivery && draft.cashAmount <= 0) {
      return const Err(ValidationFailure('Indiquez le montant à encaisser.'));
    }
    return _repo.placeOrder(draft);
  }
}

class TrackDelivery implements StreamUseCase<DeliveryTracking, String> {
  const TrackDelivery(this._repo);
  final DeliveryRepository _repo;

  @override
  Stream<DeliveryTracking> call(String orderId) => _repo.track(orderId);
}

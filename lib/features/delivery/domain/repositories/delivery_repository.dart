import '../../../../core/utils/result.dart';
import '../entities/delivery.dart';

abstract interface class DeliveryRepository {
  Future<Result<List<DeliveryQuote>>> getQuotes(DeliveryDraft draft);

  /// Renvoie l'identifiant de la commande.
  Future<Result<String>> placeOrder(DeliveryDraft draft);

  Stream<DeliveryTracking> track(String orderId);
}

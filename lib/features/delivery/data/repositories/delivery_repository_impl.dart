import '../../../../core/data/repository_guard.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/delivery.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../datasources/delivery_data_sources.dart';

class DeliveryRepositoryImpl implements DeliveryRepository {
  const DeliveryRepositoryImpl(this._remote);
  final DeliveryRemoteDataSource _remote;

  @override
  Future<Result<List<DeliveryQuote>>> getQuotes(DeliveryDraft draft) => guard(() => _remote.quotes(draft));

  @override
  Future<Result<String>> placeOrder(DeliveryDraft draft) => guard(() => _remote.placeOrder(draft));

  @override
  Stream<DeliveryTracking> track(String orderId) => _remote.track(orderId);
}

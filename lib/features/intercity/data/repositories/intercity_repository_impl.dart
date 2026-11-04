import '../../../../core/data/repository_guard.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/intercity.dart';
import '../../domain/repositories/intercity_repository.dart';
import '../datasources/intercity_data_sources.dart';

class IntercityRepositoryImpl implements IntercityRepository {
  const IntercityRepositoryImpl(this._remote);
  final IntercityRemoteDataSource _remote;

  @override
  Future<Result<List<IntercityOffer>>> search(IntercityQuery query) => guard(() => _remote.search(query));

  @override
  Future<Result<IntercityBooking>> book({
    required IntercityOffer offer,
    required int seats,
    required IntercityPayment payment,
  }) =>
      guard(() => _remote.book(offer, seats, payment));

  @override
  Future<Result<int>> cancel(String bookingId) => guard(() => _remote.cancel(bookingId));
}

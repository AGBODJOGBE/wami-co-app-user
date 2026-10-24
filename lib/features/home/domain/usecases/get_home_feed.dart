import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/home_feed.dart';
import '../repositories/home_repository.dart';

class GetHomeFeed implements UseCase<HomeFeed, NoParams> {
  const GetHomeFeed(this._repository);
  final HomeRepository _repository;

  @override
  Future<Result<HomeFeed>> call(NoParams params) => _repository.getFeed();
}

import '../../../../core/utils/result.dart';
import '../entities/home_feed.dart';

abstract interface class HomeRepository {
  Future<Result<HomeFeed>> getFeed();
}

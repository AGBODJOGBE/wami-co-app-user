import '../../../../core/data/repository_guard.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_data_sources.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  const NotificationsRepositoryImpl(this._remote);
  final NotificationsRemoteDataSource _remote;

  @override
  Future<Result<NotificationPage>> getPage(int page) => guard(() => _remote.page(page));

  @override
  Future<Result<void>> markAsRead(String id) => guard(() => _remote.markAsRead(id));
}

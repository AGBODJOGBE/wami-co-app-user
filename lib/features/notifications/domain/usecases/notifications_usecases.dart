import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/app_notification.dart';
import '../repositories/notifications_repository.dart';

class GetNotifications implements UseCase<NotificationPage, int> {
  const GetNotifications(this._repo);
  final NotificationsRepository _repo;

  @override
  Future<Result<NotificationPage>> call(int page) => _repo.getPage(page);
}

class MarkNotificationRead implements UseCase<void, String> {
  const MarkNotificationRead(this._repo);
  final NotificationsRepository _repo;

  @override
  Future<Result<void>> call(String id) => _repo.markAsRead(id);
}

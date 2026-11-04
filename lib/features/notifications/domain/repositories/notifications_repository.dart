import '../../../../core/utils/result.dart';
import '../entities/app_notification.dart';

abstract interface class NotificationsRepository {
  /// Page de notifications, les plus récentes d'abord (`page` commence à 1).
  Future<Result<NotificationPage>> getPage(int page);

  Future<Result<void>> markAsRead(String id);
}

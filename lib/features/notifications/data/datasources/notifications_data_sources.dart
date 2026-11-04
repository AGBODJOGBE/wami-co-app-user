import '../../../../core/data/fake_backend.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/app_notification.dart';

abstract interface class NotificationsRemoteDataSource {
  Future<NotificationPage> page(int page);
  Future<void> markAsRead(String id);
}

/// Routes `/api/notifications` du back wami-co.
///
/// ⚠️ On n'envoie jamais `recipientId` : le back l'accepte en paramètre et rend alors les notifications de
/// n'importe quel utilisateur (voir docs/BACKEND_A_FAIRE.md). L'identité vient du jeton.
class NotificationsApiDataSource implements NotificationsRemoteDataSource {
  const NotificationsApiDataSource(this._api, {this.pageSize = 20});
  final ApiClient _api;
  final int pageSize;

  @override
  Future<NotificationPage> page(int page) async {
    final json = await _api.get('/api/notifications', query: {'page': page, 'limit': pageSize});
    final items = (json['notifications'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    return NotificationPage(
      items: collapse(items.map(parse).toList()),
      page: (json['page'] as num?)?.toInt() ?? page,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  Future<void> markAsRead(String id) async {
    try {
      await _api.patch('/api/notifications/$id/read');
    } on BusinessRuleException catch (e) {
      // Déjà supprimée ou n'appartenant pas à l'utilisateur : rien à marquer, ce n'est pas une panne.
      if (e.code == 'NOT_FOUND' || e.code == 'FORBIDDEN') return;
      rethrow;
    }
  }

  static AppNotification parse(Map<String, dynamic> j) {
    final entity = j['relatedEntity'] as Map<String, dynamic>?;
    return AppNotification(
      id: j['id'] as String,
      type: j['type'] as String? ?? '',
      message: j['message'] as String? ?? '',
      createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
      isRead: j['isRead'] == true,
      entityType: entity?['type'] as String?,
      entityId: entity?['id'] as String?,
    );
  }

  /// Le back crée une notification par canal (SMS, push, temps réel) pour un même événement : l'écran n'en montre qu'une.
  /// Même type, même objet lié, à moins d'une minute d'écart. Le résultat reste « non lu » si l'une d'elles l'est.
  static List<AppNotification> collapse(List<AppNotification> items) {
    final kept = <AppNotification>[];
    for (final n in items) {
      final i = kept.indexWhere(
        (k) => k.type == n.type && k.entityId == n.entityId && k.createdAt.difference(n.createdAt).inSeconds.abs() < 60,
      );
      if (i == -1) {
        kept.add(n);
      } else if (!n.isRead && kept[i].isRead) {
        kept[i] = AppNotification(
          id: n.id,
          type: n.type,
          message: kept[i].message,
          createdAt: kept[i].createdAt,
          entityType: n.entityType,
          entityId: n.entityId,
        );
      }
    }
    return kept;
  }
}

class NotificationsFakeDataSource implements NotificationsRemoteDataSource {
  NotificationsFakeDataSource(this._fake);
  final FakeBackend _fake;

  late final List<AppNotification> _all = [
    AppNotification(
      id: 'n1',
      type: 'DRIVER_ASSIGNED',
      message: 'Koffi arrive dans 4 min (Bajaj Boxer, AB 1234 RB).',
      createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
      entityType: 'RIDE',
      entityId: 'r1',
    ),
    AppNotification(
      id: 'n2',
      type: 'WALLET_RECHARGED',
      message: 'Votre portefeuille a été rechargé de 5 000 F.',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: 'n3',
      type: 'RIDE_COMPLETED',
      message: 'Course terminée : 1 500 F. Merci d’avoir voyagé avec WAMI.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
      entityType: 'RIDE',
      entityId: 'r0',
    ),
  ];

  @override
  Future<NotificationPage> page(int page) async {
    await _fake.latency(0.5);
    return NotificationPage(items: page == 1 ? List.unmodifiable(_all) : const [], page: page, totalPages: 1);
  }

  @override
  Future<void> markAsRead(String id) async {
    final i = _all.indexWhere((n) => n.id == id);
    if (i != -1) _all[i] = _all[i].markedRead();
  }
}

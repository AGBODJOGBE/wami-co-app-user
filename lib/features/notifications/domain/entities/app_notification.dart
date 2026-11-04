import 'package:equatable/equatable.dart';

enum NotificationCategory { ride, delivery, wallet, other }

/// Notification reçue par le passager (course, livraison, portefeuille…).
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.entityType,
    this.entityId,
  });

  final String id;

  /// Type du back (`DRIVER_ASSIGNED`, `WALLET_RECHARGED`…).
  final String type;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? entityType;
  final String? entityId;

  AppNotification markedRead() => AppNotification(
        id: id,
        type: type,
        message: message,
        createdAt: createdAt,
        isRead: true,
        entityType: entityType,
        entityId: entityId,
      );

  NotificationCategory get category {
    if (type.startsWith('B2C_') ||
        type.startsWith('DELIVERY_') ||
        type.startsWith('PARCEL_') ||
        type.startsWith('ORDER_')) {
      return NotificationCategory.delivery;
    }
    if (type.startsWith('WALLET_') ||
        type.startsWith('P2P_') ||
        type.startsWith('WITHDRAWAL_') ||
        type == 'LOW_BALANCE_ALERT') {
      return NotificationCategory.wallet;
    }
    if (type.startsWith('RIDE_') ||
        type.startsWith('DRIVER_') ||
        type.startsWith('SCHEDULED_RIDE_') ||
        type == 'NO_DRIVER_FOUND' ||
        type == 'PASSENGER_NO_SHOW') {
      return NotificationCategory.ride;
    }
    return NotificationCategory.other;
  }

  /// Titre court en français. Le back n'envoie que le message : les types inconnus restent sans titre précis.
  String get title => _titles[type] ?? 'Notification';

  static const _titles = {
    'RIDE_REQUESTED': 'Course demandée',
    'RIDE_SEARCHING': 'Recherche d’un chauffeur',
    'DRIVER_ASSIGNED': 'Chauffeur trouvé',
    'DRIVER_EN_ROUTE': 'Chauffeur en route',
    'DRIVER_NEAR_PICKUP': 'Chauffeur tout proche',
    'DRIVER_ARRIVED': 'Chauffeur arrivé',
    'RIDE_STARTED': 'Course démarrée',
    'RIDE_RESUMED': 'Course reprise',
    'RIDE_COMPLETED': 'Course terminée',
    'RIDE_CANCELLED': 'Course annulée',
    'NO_DRIVER_FOUND': 'Aucun chauffeur disponible',
    'PASSENGER_NO_SHOW': 'Passager absent',
    'SCHEDULED_RIDE_DRIVER_ASSIGNED': 'Chauffeur pour votre réservation',
    'SCHEDULED_RIDE_DEPARTURE': 'Départ de votre réservation',
    'WALLET_RECHARGED': 'Portefeuille rechargé',
    'WALLET_RECHARGE_FAILED': 'Recharge échouée',
    'P2P_TRANSFER_RECEIVED': 'Argent reçu',
    'WALLET_GRANT_RECEIVED': 'Crédit reçu',
    'LOW_BALANCE_ALERT': 'Solde faible',
    'B2C_DELIVERY_DISPATCHED': 'Coursier en route',
    'B2C_NO_DRIVER_FOUND': 'Aucun coursier disponible',
    'B2C_DELIVERY_ORDER_CANCELLED': 'Livraison annulée',
    'B2C_RETURN_COMPLETED': 'Colis retourné',
    'DELIVERY_COMPLETED': 'Colis livré',
    'DELIVERY_FAILED': 'Livraison échouée',
    'DELIVERY_OTP': 'Code de remise',
    'PARCEL_COLLECTED': 'Colis récupéré',
  };

  @override
  List<Object?> get props => [id, type, message, createdAt, isRead, entityType, entityId];
}

class NotificationPage extends Equatable {
  const NotificationPage({required this.items, required this.page, required this.totalPages});
  final List<AppNotification> items;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;

  @override
  List<Object?> get props => [items, page, totalPages];
}

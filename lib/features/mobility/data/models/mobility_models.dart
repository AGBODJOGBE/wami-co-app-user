import '../../domain/entities/place.dart';
import '../../domain/entities/ride.dart';
import '../../domain/entities/vehicle_offer.dart';
import '../../domain/entities/waiting_policy.dart';

/// Conversions entre les réponses du back wami-co (`/api/passenger/rides/*`) et les entités du parcours Mobilité.
abstract final class MobilityModels {
  /// Statuts du back regroupés selon ce que le passager voit à l'écran.
  static RideStatus status(String? apiStatus) => switch (apiStatus) {
        'PENDING_MATCH' ||
        'BROADCAST_ACTIVE' ||
        'CARPOOLING_MATCHING' ||
        'SCHEDULED_CONFIRMED' ||
        'OPEN_FOR_SHARING' =>
          RideStatus.searching,
        'DRIVER_ASSIGNED' || 'DRIVER_EN_ROUTE' => RideStatus.driverEnRoute,
        'DRIVER_ARRIVED' => RideStatus.driverArrived,
        'IN_PROGRESS' => RideStatus.inProgress,
        'PAUSED' => RideStatus.paused,
        'COMPLETED' || 'RATED' => RideStatus.completed,
        'NO_DRIVER_FOUND' => RideStatus.noDriver,
        // Annulée (passager, chauffeur, système), passager absent, litige : la course n'ira pas à son terme.
        _ => RideStatus.cancelled,
      };

  static Map<String, dynamic> point(Place p, String prefix) => {
        '${prefix}Lat': p.lat,
        '${prefix}Lng': p.lng,
        '${prefix}Address': p.address.isEmpty ? p.name : '${p.name}, ${p.address}',
      };

  /// Réponse de `POST /rides/estimate` pour un type de véhicule.
  static VehicleOffer? offer(VehicleCategory category, Map<String, dynamic> j) {
    final price = j['finalEstimatedPrice'] ?? j['estimatedPrice'];
    if (price is! num) return null;
    final seconds = (j['durationSeconds'] as num?)?.toInt() ?? 0;
    return VehicleOffer(category: category, price: price.toInt(), etaMinutes: (seconds / 60).ceil());
  }

  /// Réponse de `GET /rides/:id`.
  ///
  /// Le back ne donne ni délai d'arrivée du chauffeur ni avancement du trajet : ils sont estimés ici à partir
  /// de la durée prévue et de l'heure de départ de la course (`now` est injectable pour les tests).
  static RideSnapshot snapshot(Map<String, dynamic> j, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final status = MobilityModels.status(j['status'] as String?);
    final category = VehicleCategory.fromApi(j['vehicleType'] as String?) ?? VehicleCategory.standard;

    final waitingFee = (j['waitingFeeFcfa'] as num?)?.toInt() ?? 0;
    final pauseFee = (j['pauseFeeFcfa'] as num?)?.toInt() ?? 0;
    final finalPrice = (j['finalPrice'] as num?)?.toInt();
    final estimated = (j['estimatedPrice'] as num?)?.toInt() ?? 0;
    final done = status == RideStatus.completed && finalPrice != null;

    final expectedMinutes = (j['estimatedDurationMin'] as num?)?.toDouble() ?? 0;
    final startedAt = DateTime.tryParse(j['startedAt'] as String? ?? '');
    var progress = 0.0;
    var eta = 0;
    if (status.isOnTrip && startedAt != null && expectedMinutes > 0) {
      final elapsed = clock.difference(startedAt).inSeconds / 60 - _pausedMinutes(j);
      progress = (elapsed / expectedMinutes).clamp(0.0, 0.97);
      eta = (expectedMinutes - elapsed).ceil().clamp(1, 999);
    }

    final freeMinutes = (j['freeWaitingMinutes'] as num?)?.toInt();
    final waitedSeconds = (j['waitingDurationSeconds'] as num?)?.toInt() ?? 0;
    final policy = freeMinutes == null
        ? null
        : WaitingPolicy(
            freeWaitingSeconds: freeMinutes * 60,
            waitingRatePerMinute: _waitingRate(waitingFee, waitedSeconds, freeMinutes * 60),
            // Le back facture la pause quand elle dépasse une franchise : on l'affiche dès qu'elle l'est.
            pauseBilled: true,
            pauseRatePerMinute: 0,
          );

    return RideSnapshot(
      id: j['rideId'] as String,
      status: status,
      category: category,
      fare: done ? finalPrice - waitingFee - pauseFee : estimated,
      serverTotal: done ? finalPrice : null,
      driver: driver(j['driver'] as Map<String, dynamic>?, j['vehicle'] as Map<String, dynamic>?),
      etaMinutes: eta,
      tripProgress: status == RideStatus.completed ? 1 : progress,
      waitedSeconds: waitedSeconds,
      pausedSeconds: _pausedSeconds(j, clock),
      waitingFee: waitingFee,
      pauseFee: pauseFee,
      policy: policy,
    );
  }

  static Driver? driver(Map<String, dynamic>? d, Map<String, dynamic>? v) {
    if (d == null) return null;
    final model = [v?['make'], v?['model']].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    final color = v?['color'] as String?;
    return Driver(
      name: '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim(),
      rating: (d['rating'] as num?)?.toDouble() ?? 0,
      vehicle: [model, color].where((s) => s != null && s.isNotEmpty).join(' · '),
      plate: v?['licensePlate'] as String? ?? '',
    );
  }

  /// Tarif à la minute déduit de ce que le serveur a déjà facturé (il ne l'expose pas directement). 0 = inconnu.
  static int _waitingRate(int fee, int waitedSeconds, int freeSeconds) {
    final billableSeconds = waitedSeconds - freeSeconds;
    if (fee <= 0 || billableSeconds <= 0) return 0;
    return (fee / (billableSeconds / 60)).round();
  }

  static int _pausedSeconds(Map<String, dynamic> j, DateTime now) {
    var total = (j['totalPausedSeconds'] as num?)?.toInt() ?? 0;
    // Pause en cours : le total du serveur ne compte que les pauses terminées.
    final history = (j['pauseHistory'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    if (history.isNotEmpty && history.last['endedAt'] == null) {
      final since = DateTime.tryParse(history.last['startedAt'] as String? ?? '');
      if (since != null) total += now.difference(since).inSeconds.clamp(0, 86400);
    }
    return total;
  }

  static double _pausedMinutes(Map<String, dynamic> j) => ((j['totalPausedSeconds'] as num?)?.toDouble() ?? 0) / 60;
}

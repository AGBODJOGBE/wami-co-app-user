import '../../domain/entities/place.dart';
import '../../domain/entities/ride.dart';
import '../../domain/entities/vehicle_offer.dart';
import '../../domain/entities/waiting_policy.dart';

/// Conversions JSON ↔ entités du parcours Mobilité. Format à valider avec le back.
abstract final class MobilityModels {
  static Place place(Map<String, dynamic> j) => Place(
        id: j['id'] as String,
        name: j['name'] as String,
        address: j['address'] as String? ?? '',
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
      );

  static Map<String, dynamic> placeToJson(Place p) => {
        'id': p.id,
        'name': p.name,
        'address': p.address,
        if (p.lat != null) 'lat': p.lat,
        if (p.lng != null) 'lng': p.lng,
      };

  static VehicleOffer offer(Map<String, dynamic> j) => VehicleOffer(
        category: VehicleCategory.values.byName(j['category'] as String),
        price: j['price'] as int,
        etaMinutes: j['eta_minutes'] as int,
        recommended: j['recommended'] as bool? ?? false,
      );

  static WaitingPolicy policy(Map<String, dynamic> j) => WaitingPolicy(
        freeWaitingSeconds: j['free_waiting_seconds'] as int,
        waitingRatePerMinute: j['waiting_rate_per_minute'] as int,
        pauseBilled: j['pause_billed'] as bool,
        pauseRatePerMinute: j['pause_rate_per_minute'] as int? ?? 0,
      );

  static RideSnapshot snapshot(Map<String, dynamic> j) {
    final d = j['driver'] as Map<String, dynamic>?;
    return RideSnapshot(
      id: j['id'] as String,
      status: RideStatus.values.byName(j['status'] as String),
      category: VehicleCategory.values.byName(j['category'] as String),
      fare: j['fare'] as int,
      driver: d == null
          ? null
          : Driver(
              name: d['name'] as String,
              rating: (d['rating'] as num).toDouble(),
              vehicle: d['vehicle'] as String,
              plate: d['plate'] as String,
            ),
      etaMinutes: j['eta_minutes'] as int? ?? 0,
      tripProgress: (j['trip_progress'] as num? ?? 0).toDouble(),
      waitedSeconds: j['waited_seconds'] as int? ?? 0,
      pausedSeconds: j['paused_seconds'] as int? ?? 0,
      waitingFee: j['waiting_fee'] as int? ?? 0,
      pauseFee: j['pause_fee'] as int? ?? 0,
    );
  }
}

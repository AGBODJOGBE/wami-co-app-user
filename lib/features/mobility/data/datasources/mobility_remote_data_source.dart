import 'dart:async';

import '../../../../core/auth/current_session.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/location/place_geocoder.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/realtime_signals.dart';
import '../../domain/entities/place.dart';
import '../../domain/entities/promo_usage.dart';
import '../../domain/entities/ride.dart';
import '../../domain/entities/vehicle_offer.dart';
import '../../domain/entities/waiting_policy.dart';
import '../models/mobility_models.dart';

abstract interface class MobilityRemoteDataSource {
  Future<List<Place>> searchPlaces(String query);
  Future<OfferQuote> estimate(Place from, Place to, {String? promoCode});
  Future<List<AvailablePromo>> availablePromos();
  Future<WaitingPolicy> waitingPolicy();
  Future<String> requestRide(Place from, Place to, VehicleCategory category, {String? promoCode});
  Stream<RideSnapshot> watchRide(String rideId);
  Future<void> cancelRide(String rideId);
  Future<void> rateRide(RideRating rating);
  Future<void> requestDestinationChange(String rideId, Place newDropoff);
  Future<PaymentSplit> setPaymentSplit(String rideId, int? walletAmount);
  Future<PromoHistory> promoHistory();
}

/// Routes `/api/passenger/rides/*` du back wami-co.
class MobilityApiDataSource implements MobilityRemoteDataSource {
  const MobilityApiDataSource(
    this._api,
    this._session,
    this._geocoder, {
    this.realtime = const NoRealtimeSignals(),
    this.pollEvery = const Duration(seconds: 3),
    this.connectedPollEvery = const Duration(seconds: 15),
    this.maxConsecutiveErrors = 5,
  });

  final ApiClient _api;
  final CurrentSession _session;
  final PlaceGeocoder _geocoder;

  /// Signaux du WebSocket : la course est relue dès qu'un statut change.
  final RealtimeSignals realtime;

  /// Interrogation régulière quand le WebSocket est coupé (ou absent).
  final Duration pollEvery;

  /// Interrogation de secours quand le WebSocket est connecté : un signal perdu est rattrapé.
  final Duration connectedPollEvery;

  /// Coupures réseau tolérées d'affilée avant d'abandonner le suivi.
  final int maxConsecutiveErrors;

  static const _base = '/api/passenger/rides';

  @override
  Future<List<Place>> searchPlaces(String query) async => [
        for (final g in await _geocoder.search(query))
          Place(id: g.id, name: g.name, address: g.address, lat: g.lat, lng: g.lng),
      ];

  /// Un appel d'estimation par type de véhicule : le back ne donne qu'un prix à la fois.
  @override
  Future<OfferQuote> estimate(Place from, Place to, {String? promoCode}) async {
    if (from.lat == null || to.lat == null) {
      throw const BusinessRuleException('rejected', 'Position introuvable pour ce trajet.');
    }
    final results = await Future.wait([
      for (final category in VehicleCategory.values) _estimateOne(from, to, category, promoCode),
    ]);
    final available = [
      for (final r in results)
        if (r.$1 case final offer?) offer,
    ];
    if (available.isEmpty) throw const BusinessRuleException('unavailable');
    // Mis en avant : le moins cher parmi les gammes qui ont des chauffeurs à proximité (sinon, le moins cher).
    final served = available.where((o) => !o.noDriverNearby).toList();
    final pool = served.isEmpty ? available : served;
    final cheapest = pool.reduce((a, b) => a.price <= b.price ? a : b);
    return OfferQuote(
      offers: [
        for (final o in available)
          VehicleOffer(
            category: o.category,
            price: o.price,
            discount: o.discount,
            arrivalMinutes: o.arrivalMinutes,
            nearbyDrivers: o.nearbyDrivers,
            recommended: o == cheapest,
          ),
      ],
      promoError: results.map((r) => r.$2).whereType<String>().firstOrNull,
    );
  }

  Future<(VehicleOffer?, String?)> _estimateOne(
    Place from,
    Place to,
    VehicleCategory category,
    String? promoCode,
  ) async {
    // Les chauffeurs proches s'interrogent en même temps que le prix.
    final nearby = _nearby(from, category);
    try {
      final json = await _api.post(
        '$_base/estimate',
        body: {
          'pickupLat': from.lat,
          'pickupLng': from.lng,
          'dropoffLat': to.lat,
          'dropoffLng': to.lng,
          'vehicleType': category.apiName,
          if (promoCode != null) 'promoCode': promoCode,
        },
      );
      final offer = MobilityModels.offer(category, json);
      final near = await nearby;
      return (
        offer == null
            ? null
            : VehicleOffer(
                category: offer.category,
                price: offer.price,
                discount: offer.discount,
                arrivalMinutes: near?.arrivalMinutes,
                nearbyDrivers: near?.count,
              ),
        MobilityModels.promoError(json),
      );
    } on BusinessRuleException {
      // Pas de tarif actif pour ce type de véhicule : on ne le propose pas.
      await nearby;
      return (null, null);
    }
  }

  /// Chauffeurs disponibles autour du départ pour une gamme. Une panne ici ne doit jamais empêcher de commander :
  /// l'information est alors simplement absente.
  Future<({int count, int? arrivalMinutes})?> _nearby(Place from, VehicleCategory category) async {
    try {
      final json = await _api.get(
        '/api/passengers/rides/nearby-drivers',
        query: {'latitude': from.lat, 'longitude': from.lng, 'vehicleType': category.apiName},
      );
      return MobilityModels.nearby(json);
    } on Exception {
      return null;
    }
  }

  @override
  Future<List<AvailablePromo>> availablePromos() async {
    final json = await _api.get('/api/passenger/promo-codes');
    return [
      for (final j in (json['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
        if (MobilityModels.availablePromo(j) case final promo?) promo,
    ];
  }

  /// Le back ne publie pas ses règles d'attente avant la course : valeurs par défaut,
  /// remplacées par celles de la course dès qu'elle existe (`RideSnapshot.policy`).
  @override
  Future<WaitingPolicy> waitingPolicy() async => const WaitingPolicy();

  @override
  Future<String> requestRide(Place from, Place to, VehicleCategory category, {String? promoCode}) async {
    final json = await _api.post(
      _base,
      body: {
        ...MobilityModels.point(from, 'pickup'),
        ...MobilityModels.point(to, 'dropoff'),
        'vehicleType': category.apiName,
        'rideType': 'STANDARD',
        // Le portefeuille d'abord, le reste en espèces : la course ne doit pas être refusée pour un solde juste.
        'paymentMethod': 'MIXED',
        'walletId': _session.walletId,
        if (promoCode != null && promoCode.isNotEmpty) 'promoCode': promoCode,
      },
    );
    return json['rideId'] as String;
  }

  @override
  Stream<RideSnapshot> watchRide(String rideId) async* {
    // Un signal reçu pendant une lecture n'est pas perdu : la lecture suivante part aussitôt.
    var signalled = false;
    Completer<void>? wake;
    final signals = realtime.ride(rideId).listen((_) {
      signalled = true;
      final w = wake;
      if (w != null && !w.isCompleted) w.complete();
    });
    try {
      var errors = 0;
      while (true) {
        signalled = false;
        try {
          final snap = MobilityModels.snapshot(await _api.get('$_base/$rideId'));
          errors = 0;
          yield snap;
          if (snap.status.isFinal) return;
        } on NetworkException {
          // Tunnel, zone sans réseau : on réessaie sans casser le suivi.
          if (++errors >= maxConsecutiveErrors) rethrow;
        } on ServerException {
          if (++errors >= maxConsecutiveErrors) rethrow;
        }
        if (!signalled) {
          final w = wake = Completer<void>();
          await Future.any([Future<void>.delayed(realtime.isConnected ? connectedPollEvery : pollEvery), w.future]);
        }
      }
    } finally {
      await signals.cancel();
    }
  }

  @override
  Future<void> cancelRide(String rideId) async {
    await _api.delete('$_base/$rideId', body: {'reason': 'Annulée par le passager'});
  }

  @override
  Future<void> rateRide(RideRating r) async {
    await _api.post(
      '$_base/${r.rideId}/rating',
      body: {
        'score': r.stars,
        if (r.tags.isNotEmpty) 'comment': r.tags.join(', '),
        // Ignoré par le back pour l'instant (champ inconnu) : à brancher quand il gèrera le pourboire.
        if (r.tip > 0) 'tip': r.tip,
      },
    );
  }

  @override
  Future<void> requestDestinationChange(String rideId, Place newDropoff) async {
    await _api.post(
      '$_base/$rideId/destination-change',
      body: {
        'newDropoffLat': newDropoff.lat,
        'newDropoffLng': newDropoff.lng,
        'newDropoffAddress': newDropoff.address.isEmpty ? newDropoff.name : newDropoff.address,
      },
    );
  }

  @override
  Future<PaymentSplit> setPaymentSplit(String rideId, int? walletAmount) async {
    final json = await _api.patch('$_base/$rideId/payment-split', body: {'walletAmount': walletAmount});
    return PaymentSplit(
      walletAmount: (json['requestedWalletAmount'] as num?)?.toInt(),
      cashAmount: (json['estimatedCashAmount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<PromoHistory> promoHistory() async {
    final json = await _api.get('/api/passenger/promo-codes/usages');
    return MobilityModels.promoHistory(json);
  }
}

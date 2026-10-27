import 'dart:async';

import '../../../../core/auth/current_session.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/location/place_geocoder.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/realtime_signals.dart';
import '../../domain/entities/place.dart';
import '../../domain/entities/ride.dart';
import '../../domain/entities/vehicle_offer.dart';
import '../../domain/entities/waiting_policy.dart';
import '../models/mobility_models.dart';

abstract interface class MobilityRemoteDataSource {
  Future<List<Place>> searchPlaces(String query);
  Future<List<VehicleOffer>> estimate(Place from, Place to);
  Future<WaitingPolicy> waitingPolicy();
  Future<String> requestRide(Place from, Place to, VehicleCategory category);
  Stream<RideSnapshot> watchRide(String rideId);
  Future<void> cancelRide(String rideId);
  Future<void> rateRide(RideRating rating);
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
  Future<List<VehicleOffer>> estimate(Place from, Place to) async {
    if (from.lat == null || to.lat == null) {
      throw const BusinessRuleException('rejected', 'Position introuvable pour ce trajet.');
    }
    final offers = await Future.wait([
      for (final category in VehicleCategory.values) _estimateOne(from, to, category),
    ]);
    final available = offers.whereType<VehicleOffer>().toList();
    if (available.isEmpty) throw const BusinessRuleException('unavailable');
    // Mis en avant : le moins cher.
    final cheapest = available.reduce((a, b) => a.price <= b.price ? a : b);
    return [
      for (final o in available)
        VehicleOffer(category: o.category, price: o.price, etaMinutes: o.etaMinutes, recommended: o == cheapest),
    ];
  }

  Future<VehicleOffer?> _estimateOne(Place from, Place to, VehicleCategory category) async {
    try {
      final json = await _api.post(
        '$_base/estimate',
        body: {
          'pickupLat': from.lat,
          'pickupLng': from.lng,
          'dropoffLat': to.lat,
          'dropoffLng': to.lng,
          'vehicleType': category.apiName,
        },
      );
      return MobilityModels.offer(category, json);
    } on BusinessRuleException {
      // Pas de tarif actif pour ce type de véhicule : on ne le propose pas.
      return null;
    }
  }

  /// Le back ne publie pas ses règles d'attente avant la course : valeurs par défaut,
  /// remplacées par celles de la course dès qu'elle existe (`RideSnapshot.policy`).
  @override
  Future<WaitingPolicy> waitingPolicy() async => const WaitingPolicy();

  @override
  Future<String> requestRide(Place from, Place to, VehicleCategory category) async {
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
}

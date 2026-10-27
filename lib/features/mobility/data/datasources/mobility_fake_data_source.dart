import 'dart:async';

import '../../../../core/data/fake_backend.dart';
import '../../domain/entities/place.dart';
import '../../domain/entities/ride.dart';
import '../../domain/entities/vehicle_offer.dart';
import '../../domain/entities/waiting_policy.dart';
import 'mobility_remote_data_source.dart';

/// Backend simulé : lieux, prix et déroulé complet d'une course
/// (recherche → chauffeur en route → arrivé + attente → course → pause → fin).
class MobilityFakeDataSource implements MobilityRemoteDataSource {
  MobilityFakeDataSource(this._fake, {this.tick = const Duration(seconds: 1)});

  final FakeBackend _fake;

  /// Durée d'un pas de simulation (réduite dans les tests).
  final Duration tick;

  static const _policy = WaitingPolicy();
  final _rides = <String, VehicleCategory>{};
  final _cancelled = <String>{};

  /// Prix et délais d'exemple : grille tarifaire à valider.
  static const _grid = {
    VehicleCategory.moto: (800, 3),
    VehicleCategory.tricycle: (1200, 6),
    VehicleCategory.eco: (1500, 5),
    VehicleCategory.standard: (2000, 5),
    VehicleCategory.confort: (2800, 7),
    VehicleCategory.vip: (5000, 9),
    VehicleCategory.van: (6500, 12),
  };

  static const _places = [
    Place(id: 'pl1', name: 'Marché Dantokpa', address: 'Cotonou'),
    Place(id: 'pl2', name: 'Aéroport Cardinal Bernardin Gantin', address: 'Cadjèhoun, Cotonou'),
    Place(id: 'pl3', name: 'Place de l’Étoile Rouge', address: 'Cotonou'),
    Place(id: 'pl4', name: 'Fidjrossè Plage', address: 'Cotonou'),
    Place(id: 'pl5', name: 'Université d’Abomey-Calavi', address: 'Abomey-Calavi'),
    Place(id: 'pl6', name: 'Gare routière de Godomey', address: 'Godomey'),
  ];

  @override
  Future<List<Place>> searchPlaces(String query) async {
    await _fake.latency(0.4);
    final q = query.toLowerCase();
    return _places.where((p) => p.name.toLowerCase().contains(q) || p.address.toLowerCase().contains(q)).toList();
  }

  @override
  Future<List<VehicleOffer>> estimate(Place from, Place to) async {
    await _fake.latency();
    return [
      for (final c in VehicleCategory.values)
        VehicleOffer(
          category: c,
          price: _grid[c]!.$1,
          etaMinutes: _grid[c]!.$2,
          recommended: c == VehicleCategory.moto,
        ),
    ];
  }

  @override
  Future<WaitingPolicy> waitingPolicy() async {
    await _fake.latency(0.2);
    return _policy;
  }

  @override
  Future<String> requestRide(Place from, Place to, VehicleCategory category) async {
    await _fake.latency();
    final id = _fake.reference();
    _rides[id] = category;
    return id;
  }

  @override
  Stream<RideSnapshot> watchRide(String rideId) async* {
    final category = _rides[rideId] ?? VehicleCategory.moto;
    const driver = Driver(name: '[Nom du chauffeur]', rating: 4.9, vehicle: 'Moto · Bajaj Boxer', plate: '[PLAQUE]');
    var snap = RideSnapshot(
      id: rideId,
      status: RideStatus.searching,
      category: category,
      fare: _grid[category]!.$1,
      securityCode: '4821',
    );
    yield snap;

    var step = 0;
    var resumedAfterPause = false;
    while (!_cancelled.contains(rideId)) {
      await Future<void>.delayed(tick);
      step++;
      switch (snap.status) {
        case RideStatus.searching:
          if (step >= 4) snap = snap.copyWith(status: RideStatus.driverEnRoute, driver: driver, etaMinutes: 4);
        case RideStatus.driverEnRoute:
          final eta = 4 - (step - 4) ~/ 2;
          snap = eta <= 0
              // Démo : l'attente démarre à 1 min 40 pour voir vite la facturation.
              ? snap.copyWith(status: RideStatus.driverArrived, etaMinutes: 0, waitedSeconds: 100)
              : snap.copyWith(etaMinutes: eta);
        case RideStatus.driverArrived:
          final waited = snap.waitedSeconds + 1;
          snap = snap.copyWith(waitedSeconds: waited, waitingFee: _policy.waitingFee(waited));
          if (waited >= 135) snap = snap.copyWith(status: RideStatus.inProgress, etaMinutes: 12);
        case RideStatus.inProgress:
          final progress = (snap.tripProgress + 0.04).clamp(0.0, 1.0);
          snap = snap.copyWith(tripProgress: progress, etaMinutes: ((1 - progress) * 12).ceil());
          if (!resumedAfterPause && progress >= 0.36) snap = snap.copyWith(status: RideStatus.paused);
          if (progress >= 1) snap = snap.copyWith(status: RideStatus.completed, etaMinutes: 0);
        case RideStatus.paused:
          final paused = snap.pausedSeconds + 1;
          snap = snap.copyWith(pausedSeconds: paused, pauseFee: _policy.pauseFee(paused));
          if (paused >= 8) {
            resumedAfterPause = true;
            snap = snap.copyWith(status: RideStatus.inProgress);
          }
        case RideStatus.completed:
        case RideStatus.cancelled:
        case RideStatus.noDriver:
          return;
      }
      yield snap;
    }
    yield snap.copyWith(status: RideStatus.cancelled);
  }

  @override
  Future<void> cancelRide(String rideId) async {
    await _fake.latency(0.5);
    _cancelled.add(rideId);
  }

  @override
  Future<void> rateRide(RideRating rating) => _fake.latency();
}

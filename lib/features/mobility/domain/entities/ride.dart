import 'package:equatable/equatable.dart';

import 'vehicle_offer.dart';
import 'waiting_policy.dart';

enum RideStatus {
  /// Recherche d'un chauffeur.
  searching,

  /// Chauffeur en route vers le point de départ.
  driverEnRoute,

  /// Chauffeur arrivé : le compteur d'attente tourne.
  driverArrived,

  /// Course démarrée : appel et message disparaissent.
  inProgress,

  /// Le chauffeur a mis la course en pause.
  paused,

  completed,
  cancelled,

  /// Aucun chauffeur n'a accepté la course.
  noDriver;

  /// Appeler / écrire au chauffeur n'est possible qu'avant le démarrage.
  bool get canContactDriver => this == driverEnRoute || this == driverArrived;

  bool get isOnTrip => this == inProgress || this == paused;

  /// Plus rien à suivre : le flux de la course s'arrête.
  bool get isFinal => this == completed || this == cancelled || this == noDriver;
}

class Driver extends Equatable {
  const Driver({
    required this.name,
    required this.rating,
    required this.vehicle,
    required this.plate,
  });

  final String name;
  final double rating;
  final String vehicle;
  final String plate;

  @override
  List<Object?> get props => [name, rating, vehicle, plate];
}

/// État instantané d'une course, poussé par le serveur.
class RideSnapshot extends Equatable {
  const RideSnapshot({
    required this.id,
    required this.status,
    required this.category,
    required this.fare,
    this.driver,
    this.etaMinutes = 0,
    this.tripProgress = 0,
    this.waitedSeconds = 0,
    this.pausedSeconds = 0,
    this.waitingFee = 0,
    this.pauseFee = 0,
    this.policy,
    this.serverTotal,
  });

  final String id;
  final RideStatus status;
  final VehicleCategory category;
  final Driver? driver;

  /// Minutes avant l'arrivée du chauffeur (ou à destination pendant la course).
  final int etaMinutes;

  /// Avancement de la course, de 0 à 1.
  final double tripProgress;

  final int waitedSeconds;
  final int pausedSeconds;

  /// Prix de la course, hors attente et pause.
  final int fare;
  final int waitingFee;
  final int pauseFee;

  /// Règles d'attente telles que le serveur les applique à cette course, quand il les donne.
  final WaitingPolicy? policy;

  /// Montant définitif donné par le serveur à la fin de la course (réduction et approche comprises).
  final int? serverTotal;

  int get total => serverTotal ?? fare + waitingFee + pauseFee;

  RideSnapshot copyWith({
    RideStatus? status,
    Driver? driver,
    int? etaMinutes,
    double? tripProgress,
    int? waitedSeconds,
    int? pausedSeconds,
    int? waitingFee,
    int? pauseFee,
  }) {
    return RideSnapshot(
      id: id,
      status: status ?? this.status,
      category: category,
      fare: fare,
      driver: driver ?? this.driver,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      tripProgress: tripProgress ?? this.tripProgress,
      waitedSeconds: waitedSeconds ?? this.waitedSeconds,
      pausedSeconds: pausedSeconds ?? this.pausedSeconds,
      waitingFee: waitingFee ?? this.waitingFee,
      pauseFee: pauseFee ?? this.pauseFee,
      policy: policy,
      serverTotal: serverTotal,
    );
  }

  @override
  List<Object?> get props => [
        id,
        status,
        category,
        driver,
        etaMinutes,
        tripProgress,
        waitedSeconds,
        pausedSeconds,
        fare,
        waitingFee,
        pauseFee,
        policy,
        serverTotal,
      ];
}

/// Note laissée en fin de course. Le paiement est prélevé automatiquement à l'arrivée : pas de pourboire pour l'instant.
class RideRating extends Equatable {
  const RideRating({required this.rideId, required this.stars, this.tags = const {}});

  final String rideId;
  final int stars;
  final Set<String> tags;

  @override
  List<Object?> get props => [rideId, stars, tags];
}

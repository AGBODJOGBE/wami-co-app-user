import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wami/core/auth/auth_session.dart';
import 'package:wami/core/auth/current_session.dart';
import 'package:wami/core/error/exceptions.dart';
import 'package:wami/core/network/realtime_signals.dart';
import 'package:wami/features/mobility/data/datasources/mobility_remote_data_source.dart';
import 'package:wami/core/location/place_geocoder.dart';
import 'package:wami/features/mobility/data/models/mobility_models.dart';
import 'package:wami/features/mobility/domain/entities/place.dart';
import 'package:wami/features/mobility/domain/entities/ride.dart';
import 'package:wami/features/mobility/domain/entities/vehicle_offer.dart';

import '../../support/stub_server.dart';

class _NoGeocoder implements PlaceGeocoder {
  @override
  Future<List<GeocodedPlace>> search(String query) async => const [];
}

/// WebSocket simulé : `fire` envoie un signal de changement de statut.
class _FakeSignals implements RealtimeSignals {
  final _controller = StreamController<void>.broadcast();

  bool get listening => _controller.hasListener;

  void fire() => _controller.add(null);

  @override
  bool get isConnected => true;

  @override
  Stream<void> ride(String rideId) => _controller.stream;
}

const _from = Place(id: 'me', name: 'Ma position', address: 'Position actuelle', lat: 6.36, lng: 2.41);
const _to = Place(id: '9', name: 'Dantokpa', address: 'Cotonou', lat: 6.37, lng: 2.43);

Map<String, dynamic> _ride(String status, {Map<String, dynamic>? extra}) => {
      'rideId': 'r1',
      'status': status,
      'vehicleType': 'CONFORT',
      'estimatedPrice': 2800,
      'estimatedDurationMin': 20,
      'driver': {'firstName': 'Koffi', 'lastName': 'Adjovi', 'rating': 4.8},
      'vehicle': {'make': 'Toyota', 'model': 'Yaris', 'color': 'Gris', 'licensePlate': 'AB 1234 RB'},
      ...?extra,
    };

void main() {
  group('statuts', () {
    test('regroupés selon ce que voit le passager', () {
      expect(MobilityModels.status('PENDING_MATCH'), RideStatus.searching);
      expect(MobilityModels.status('BROADCAST_ACTIVE'), RideStatus.searching);
      expect(MobilityModels.status('DRIVER_ASSIGNED'), RideStatus.driverEnRoute);
      expect(MobilityModels.status('DRIVER_ARRIVED'), RideStatus.driverArrived);
      expect(MobilityModels.status('IN_PROGRESS'), RideStatus.inProgress);
      expect(MobilityModels.status('PAUSED'), RideStatus.paused);
      expect(MobilityModels.status('COMPLETED'), RideStatus.completed);
      expect(MobilityModels.status('RATED'), RideStatus.completed);
      expect(MobilityModels.status('NO_DRIVER_FOUND'), RideStatus.noDriver);
      expect(MobilityModels.status('CANCELLED_DRIVER'), RideStatus.cancelled);
      expect(MobilityModels.status('NO_SHOW_PASSENGER'), RideStatus.cancelled);
    });
  });

  group('snapshot', () {
    test('chauffeur et véhicule', () {
      final s = MobilityModels.snapshot(_ride('DRIVER_EN_ROUTE'));
      expect(s.category, VehicleCategory.confort);
      expect(s.driver!.name, 'Koffi Adjovi');
      expect(s.driver!.vehicle, 'Toyota Yaris · Gris');
      expect(s.driver!.plate, 'AB 1234 RB');
      expect(s.fare, 2800);
    });

    test('attente facturée : franchise du serveur et tarif déduit', () {
      final s = MobilityModels.snapshot(
        _ride(
          'DRIVER_ARRIVED',
          extra: {'freeWaitingMinutes': 3, 'waitingDurationSeconds': 300, 'waitingFeeFcfa': 100},
        ),
      );
      expect(s.waitedSeconds, 300);
      expect(s.waitingFee, 100);
      expect(s.policy!.freeWaitingSeconds, 180);
      // 2 minutes facturées, 100 F : 50 F la minute.
      expect(s.policy!.waitingRatePerMinute, 50);
    });

    test('course en cours : avancement et temps restant estimés', () {
      final start = DateTime.utc(2026, 10, 24, 10);
      final s = MobilityModels.snapshot(
        _ride('IN_PROGRESS', extra: {'startedAt': start.toIso8601String()}),
        now: start.add(const Duration(minutes: 5)),
      );
      expect(s.tripProgress, closeTo(0.25, 0.001));
      expect(s.etaMinutes, 15);
    });

    test('pause en cours : le temps écoulé depuis son début est compté', () {
      final paused = DateTime.utc(2026, 10, 24, 10, 10);
      final s = MobilityModels.snapshot(
        _ride(
          'PAUSED',
          extra: {
            'totalPausedSeconds': 60,
            'pauseHistory': [
              {'startedAt': '2026-10-24T10:00:00.000Z', 'endedAt': '2026-10-24T10:01:00.000Z'},
              {'startedAt': paused.toIso8601String(), 'endedAt': null},
            ],
          },
        ),
        now: paused.add(const Duration(seconds: 90)),
      );
      expect(s.pausedSeconds, 150);
    });

    test('course terminée : le total du serveur fait foi', () {
      final s = MobilityModels.snapshot(
        _ride('COMPLETED', extra: {'finalPrice': 3000, 'waitingFeeFcfa': 100, 'pauseFeeFcfa': 50}),
      );
      expect(s.total, 3000);
      expect(s.fare, 2850);
      expect(s.tripProgress, 1);
    });
  });

  group('source de données', () {
    late StubServer server;
    late MobilityApiDataSource rides;

    setUp(() {
      server = StubServer();
      final session = CurrentSession()
        ..set(
          const AuthSession(
            token: 't',
            userId: 'u',
            passengerId: 'p',
            walletId: 'w1',
            phone: '+2290197123456',
            firstName: 'Awa',
            lastName: 'Dossou',
          ),
        );
      rides = MobilityApiDataSource(
        server.client(session: session),
        session,
        _NoGeocoder(),
        pollEvery: Duration.zero,
        maxConsecutiveErrors: 3,
      );
    });

    test('estimation : un appel par type, les types sans tarif sont écartés, le moins cher est recommandé', () async {
      server
        ..on('POST /api/passenger/rides/estimate', {
          'success': true,
          'data': {'estimatedPrice': 900, 'durationSeconds': 600},
        })
        ..on('POST /api/passenger/rides/estimate', {'success': false, 'error': 'No pricing'}, status: 400)
        ..on('POST /api/passenger/rides/estimate', {
          'success': true,
          'data': {'estimatedPrice': 2500, 'durationSeconds': 700},
        });

      final offers = (await rides.estimate(_from, _to)).offers;

      expect(server.count('POST /api/passenger/rides/estimate'), VehicleCategory.values.length);
      expect(offers, isNotEmpty);
      expect(offers.where((o) => o.recommended), hasLength(1));
      expect(offers.firstWhere((o) => o.recommended).price, 900);
      expect(server.requests.firstWhere((r) => r.method == 'POST').data, containsPair('vehicleType', 'MOTO'));
    });

    test('délai d’arrivée et chauffeurs proches par gamme', () async {
      server
        ..on('POST /api/passenger/rides/estimate', {
          'success': true,
          'data': {'estimatedPrice': 1000, 'durationSeconds': 600},
        })
        ..on('GET /api/passengers/rides/nearby-drivers?vehicleType=MOTO', {
          'success': true,
          'data': {
            'count': 2,
            'drivers': [
              {'driverId': 'a', 'estimatedArrivalMin': 3},
              {'driverId': 'b', 'estimatedArrivalMin': 1},
            ],
          },
        })
        ..on('GET /api/passengers/rides/nearby-drivers?vehicleType=VAN', {
          'success': true,
          'data': {'count': 0, 'drivers': []},
        })
        // Les autres gammes : le service des chauffeurs proches est en panne, la commande reste possible.
        ..on('GET /api/passengers/rides/nearby-drivers', {'success': false, 'error': 'boom'}, status: 500);

      final offers = (await rides.estimate(_from, _to)).offers;
      VehicleOffer offerOf(VehicleCategory c) => offers.firstWhere((o) => o.category == c);

      final moto = offerOf(VehicleCategory.moto);
      expect(moto.nearbyDrivers, 2);
      expect(moto.arrivalMinutes, 1, reason: 'le chauffeur le plus proche');
      final van = offerOf(VehicleCategory.van);
      expect(van.nearbyDrivers, 0);
      expect(van.arrivalMinutes, isNull);
      expect(van.noDriverNearby, isTrue);
      final confort = offerOf(VehicleCategory.confort);
      expect(confort.nearbyDrivers, isNull, reason: 'information indisponible, pas « aucun chauffeur »');
      expect(confort.noDriverNearby, isFalse);
      // La position du passager est envoyée.
      final query = server.requests.firstWhere((r) => r.path.contains('nearby-drivers')).queryParameters;
      expect(query['latitude'], 6.36);
      expect(query['longitude'], 2.41);
    });

    test('mis en avant : le moins cher parmi les gammes qui ont des chauffeurs', () async {
      // Estimations dans l'ordre des gammes : la moto (1re) est la moins chère mais sans chauffeur.
      final prices = {for (var i = 0; i < VehicleCategory.values.length; i++) VehicleCategory.values[i]: 500 + i * 100};
      for (final entry in prices.entries) {
        server.on('POST /api/passenger/rides/estimate', {
          'success': true,
          'data': {'estimatedPrice': entry.value, 'durationSeconds': 60},
        });
      }
      server
        ..on('GET /api/passengers/rides/nearby-drivers?vehicleType=MOTO', {
          'success': true,
          'data': {'count': 0, 'drivers': []},
        })
        ..on('GET /api/passengers/rides/nearby-drivers', {
          'success': true,
          'data': {
            'count': 1,
            'drivers': [
              {'estimatedArrivalMin': 4},
            ],
          },
        });
      final offers = (await rides.estimate(_from, _to)).offers;
      final recommended = offers.singleWhere((o) => o.recommended);
      expect(recommended.category, isNot(VehicleCategory.moto));
      expect(recommended.nearbyDrivers, 1);
    });

    test('estimation avec code promo : le code part, le prix remisé est lu', () async {
      server.on('POST /api/passenger/rides/estimate', {
        'success': true,
        'data': {
          'estimatedPrice': 1529,
          'finalEstimatedPrice': 1392,
          'discountAmount': 137,
          'durationSeconds': 600,
          'promoDisplayText': '300 F offerts',
        },
      });
      final quote = await rides.estimate(_from, _to, promoCode: 'NOUVEAU300');
      expect(server.requests.firstWhere((r) => r.method == 'POST').data, containsPair('promoCode', 'NOUVEAU300'));
      expect(quote.promoError, isNull);
      expect(quote.offers.first.price, 1392);
      expect(quote.offers.first.discount, 137);
      expect(quote.offers.first.fullPrice, 1529);
    });

    test('code promo refusé : motif en français, prix sans remise', () async {
      server.on('POST /api/passenger/rides/estimate', {
        'success': true,
        'data': {
          'estimatedPrice': 1529,
          'durationSeconds': 600,
          'promoError': "PromoCode with id 'ZZZ' not found",
        },
      });
      final quote = await rides.estimate(_from, _to, promoCode: 'ZZZ');
      expect(quote.promoError, 'Code promo inconnu.');
      expect(quote.offers.first.price, 1529);
      expect(quote.offers.first.discount, 0);
    });

    test('code promo refusé avec un motif déjà en français : gardé tel quel', () async {
      server.on('POST /api/passenger/rides/estimate', {
        'success': true,
        'data': {
          'estimatedPrice': 1000,
          'durationSeconds': 60,
          'promoError': 'Ce code promo est réservé aux clients actifs.',
        },
      });
      expect(
        (await rides.estimate(_from, _to, promoCode: 'X')).promoError,
        'Ce code promo est réservé aux clients actifs.',
      );
    });

    test('codes disponibles : seuls le code et son texte sont retenus', () async {
      server.on('GET /api/passenger/promo-codes', {
        'success': true,
        'data': [
          {
            'id': 'p1',
            'code': 'NOUVEAU300',
            'displayText': '300 F offerts',
            'realCostAccrued': 1234,
            'marginResidualPct': 20,
            'targetUserIds': ['autre-utilisateur'],
          },
          {'id': 'p2', 'displayText': 'sans code'},
        ],
      });
      final promos = await rides.availablePromos();
      expect(promos.single.code, 'NOUVEAU300');
      expect(promos.single.displayText, '300 F offerts');
    });

    test('estimation impossible : aucun type disponible', () {
      server.on('POST /api/passenger/rides/estimate', {'success': false, 'error': 'No pricing'}, status: 400);
      expect(() => rides.estimate(_from, _to), throwsA(isA<BusinessRuleException>()));
    });

    test('demande de course : coordonnées, portefeuille, paiement mixte', () async {
      server.on(
        'POST /api/passenger/rides',
        {
          'success': true,
          'data': {'rideId': 'r1'},
        },
        status: 201,
      );

      final id = await rides.requestRide(_from, _to, VehicleCategory.confort, promoCode: 'NOUVEAU300');

      expect(id, 'r1');
      expect(server.last('POST /api/passenger/rides')!.data, {
        'pickupLat': 6.36,
        'pickupLng': 2.41,
        'pickupAddress': 'Ma position, Position actuelle',
        'dropoffLat': 6.37,
        'dropoffLng': 2.43,
        'dropoffAddress': 'Dantokpa, Cotonou',
        'vehicleType': 'CONFORT',
        'rideType': 'STANDARD',
        'paymentMethod': 'MIXED',
        'walletId': 'w1',
        'promoCode': 'NOUVEAU300',
      });
    });

    test('suivi : survit à une coupure réseau et s’arrête à la fin de la course', () async {
      server
        ..on('GET /api/passenger/rides/r1', {'success': true, 'data': _ride('PENDING_MATCH')})
        ..cutOnce('GET /api/passenger/rides/r1')
        ..on('GET /api/passenger/rides/r1', {'success': true, 'data': _ride('DRIVER_EN_ROUTE')})
        ..on('GET /api/passenger/rides/r1', {
          'success': true,
          'data': _ride('COMPLETED', extra: {'finalPrice': 2800}),
        });

      final seen = await rides.watchRide('r1').map((s) => s.status).toList();

      expect(seen, [RideStatus.searching, RideStatus.driverEnRoute, RideStatus.completed]);
    });

    test('suivi temps réel : chaque signal du WebSocket relit la course aussitôt', () async {
      final signals = _FakeSignals();
      final live = MobilityApiDataSource(
        server.client(session: CurrentSession()),
        CurrentSession(),
        _NoGeocoder(),
        realtime: signals,
        // Sans signal, aucune relecture avant une heure : seuls les signaux font avancer le suivi.
        pollEvery: const Duration(hours: 1),
        connectedPollEvery: const Duration(hours: 1),
      );
      server
        ..on('GET /api/passenger/rides/r1', {'success': true, 'data': _ride('PENDING_MATCH')})
        ..on('GET /api/passenger/rides/r1', {'success': true, 'data': _ride('DRIVER_ARRIVED')})
        ..on('GET /api/passenger/rides/r1', {
          'success': true,
          'data': _ride('COMPLETED', extra: {'finalPrice': 2800}),
        });

      final seen = <RideStatus>[];
      final done = live.watchRide('r1').map((s) => s.status).forEach((s) {
        seen.add(s);
        // Le back annonce le changement suivant juste après chaque lecture.
        Future<void>.delayed(Duration.zero, signals.fire);
      });
      await done.timeout(const Duration(seconds: 5));

      expect(seen, [RideStatus.searching, RideStatus.driverArrived, RideStatus.completed]);
      expect(signals.listening, isFalse, reason: 'la salle de la course est quittée à la fin du suivi');
    });

    test('suivi temps réel : un signal reçu pendant une lecture n’est pas perdu', () async {
      final signals = _FakeSignals();
      final live = MobilityApiDataSource(
        server.client(session: CurrentSession()),
        CurrentSession(),
        _NoGeocoder(),
        realtime: signals,
        pollEvery: const Duration(hours: 1),
        connectedPollEvery: const Duration(hours: 1),
      );
      server
        ..on('GET /api/passenger/rides/r1', {'success': true, 'data': _ride('IN_PROGRESS')})
        ..on('GET /api/passenger/rides/r1', {
          'success': true,
          'data': _ride('COMPLETED', extra: {'finalPrice': 2800}),
        });
      // Le signal arrive avant même la fin de la première lecture.
      server.onRequest = signals.fire;

      final seen = await live.watchRide('r1').map((s) => s.status).toList().timeout(const Duration(seconds: 5));

      expect(seen, [RideStatus.inProgress, RideStatus.completed]);
    });

    test('suivi : abandonne après trop de coupures d’affilée', () {
      server
        ..cutOnce('GET /api/passenger/rides/r1')
        ..cutOnce('GET /api/passenger/rides/r1')
        ..cutOnce('GET /api/passenger/rides/r1')
        ..cutOnce('GET /api/passenger/rides/r1');
      expect(rides.watchRide('r1').toList(), throwsA(isA<NetworkException>()));
    });

    test('suivi : un jeton refusé n’est pas retenté', () {
      server.on(
        'GET /api/passenger/rides/r1',
        {
          'success': false,
          'error': {'code': 'SESSION_EXPIRED', 'message': 'Session expirée'},
        },
        status: 401,
      );
      expect(rides.watchRide('r1').toList(), throwsA(isA<UnauthorizedException>()));
    });

    test('annulation et note', () async {
      server
        ..on('DELETE /api/passenger/rides/r1', {'success': true})
        ..on('POST /api/passenger/rides/r1/rating', {'success': true});

      await rides.cancelRide('r1');
      await rides.rateRide(const RideRating(rideId: 'r1', stars: 4, tags: {'Ponctuel', 'Conduite sûre'}));

      expect(server.last('DELETE /api/passenger/rides/r1')!.data, {'reason': 'Annulée par le passager'});
      expect(server.last('POST /api/passenger/rides/r1/rating')!.data, {
        'score': 4,
        'comment': 'Ponctuel, Conduite sûre',
      });
    });
  });
}

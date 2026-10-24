import 'package:flutter_test/flutter_test.dart';
import 'package:wami/core/auth/auth_session.dart';
import 'package:wami/core/auth/current_session.dart';
import 'package:wami/core/error/exceptions.dart';
import 'package:wami/features/mobility/data/datasources/mobility_remote_data_source.dart';
import 'package:wami/features/mobility/data/datasources/place_geocoder.dart';
import 'package:wami/features/mobility/data/models/mobility_models.dart';
import 'package:wami/features/mobility/domain/entities/place.dart';
import 'package:wami/features/mobility/domain/entities/ride.dart';
import 'package:wami/features/mobility/domain/entities/vehicle_offer.dart';

import '../../support/stub_server.dart';

class _NoGeocoder implements PlaceGeocoder {
  @override
  Future<List<Place>> search(String query) async => const [];
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

      final offers = await rides.estimate(_from, _to);

      expect(server.count('POST /api/passenger/rides/estimate'), VehicleCategory.values.length);
      expect(offers, isNotEmpty);
      expect(offers.where((o) => o.recommended), hasLength(1));
      expect(offers.firstWhere((o) => o.recommended).price, 900);
      expect(server.requests.first.data, containsPair('vehicleType', 'MOTO'));
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

      final id = await rides.requestRide(_from, _to, VehicleCategory.confort);

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

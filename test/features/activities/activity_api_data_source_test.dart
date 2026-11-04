import 'package:flutter_test/flutter_test.dart';
import 'package:wami/core/domain/service_type.dart';
import 'package:wami/core/error/exceptions.dart';
import 'package:wami/features/activities/data/activity_repository_impl.dart';
import 'package:wami/features/activities/domain/activity.dart';

import '../../support/stub_server.dart';

const _rides = 'GET /api/passengers/rides';
const _deliveries = 'GET /api/passenger/delivery';

Map<String, dynamic> _delivery(String id, String status, {String? scheduledAt, bool driver = false, num? finalPrice}) =>
    {
      'id': id,
      'status': status,
      'dropoff': {'address': 'Fidjrossè'},
      'driver': driver ? {'name': 'Koffi'} : null,
      'estimatedPrice': 1500,
      'finalPrice': finalPrice,
      'scheduledAt': scheduledAt,
      'createdAt': '2026-10-24T08:00:00.000Z',
    };

Map<String, dynamic> _ride(
  String id,
  String status, {
  bool driver = false,
  num? finalPrice,
  String? scheduledAt,
  String dropoff = 'Dantokpa, Cotonou',
}) =>
    {
      'rideId': id,
      'status': status,
      'dropoff': {'address': dropoff},
      'driver': driver ? {'firstName': 'Koffi', 'lastName': 'Adjovi'} : null,
      'estimatedPrice': 800,
      'finalPrice': finalPrice,
      'scheduledAt': scheduledAt,
      'createdAt': '2026-10-25T08:00:00.000Z',
    };

Map<String, dynamic> _ok(Object data) => {'success': true, 'data': data};

void main() {
  group('courses', () {
    late StubServer server;

    setUp(() => server = StubServer());

    test('statut, titre, chauffeur et montant', () async {
      server.on(_deliveries, _ok([]));
      server.on(
        _rides,
        _ok({
          'total': 6,
          'rides': [
            _ride('a', 'IN_PROGRESS', driver: true),
            _ride('b', 'COMPLETED', driver: true, finalPrice: 1000),
            _ride('c', 'CANCELLED_PASSENGER'),
            _ride('d', 'NO_DRIVER_FOUND'),
            _ride('e', 'SCHEDULED_CONFIRMED', scheduledAt: '2999-01-01T10:00:00.000Z'),
            _ride('f', 'PENDING_MATCH'),
          ],
        }),
      );

      final items = await ActivityApiDataSource(server.client()).fetch();

      expect(items.map((a) => a.status), [
        ActivityStatus.ongoing,
        ActivityStatus.done,
        ActivityStatus.cancelled,
        ActivityStatus.cancelled,
        ActivityStatus.upcoming,
        ActivityStatus.ongoing,
      ]);
      expect(items.every((a) => a.service == ServiceType.mobility), isTrue);
      expect(items[0].title, 'Course vers Dantokpa, Cotonou');
      expect(items[0].subtitle, 'Chauffeur : Koffi Adjovi');
      expect(items[1].subtitle, 'Terminée · Koffi Adjovi');
      expect(items[1].amount, 1000);
      // Course annulée : rien à payer.
      expect(items[2].amount, 0);
      expect(items[3].subtitle, 'Aucun chauffeur disponible');
      // Réservation : la date affichée est celle du départ prévu.
      expect(items[4].date.year, 2999);
      expect(items[5].subtitle, 'Recherche d’un chauffeur');
      expect(items[5].amount, 800);
    });

    test('courses et livraisons réunies', () async {
      server
        ..on(
          _rides,
          _ok({
            'total': 1,
            'rides': [_ride('r1', 'COMPLETED', finalPrice: 900)],
          }),
        )
        ..on(_deliveries, _ok([_delivery('d1', 'IN_TRANSIT', driver: true)]));
      final items = await ActivityApiDataSource(server.client()).fetch();
      expect(items.map((a) => a.service).toSet(), {ServiceType.mobility, ServiceType.delivery});
    });

    test('historique des courses en erreur serveur : les livraisons restent affichées', () async {
      server
        ..on(_rides, {'success': false, 'error': 'Failed to reconstruct RideNumber'}, status: 500)
        ..on(_deliveries, _ok([_delivery('d1', 'COMPLETED', finalPrice: 1700)]));
      final items = await ActivityApiDataSource(server.client()).fetch();
      expect(items.single.service, ServiceType.delivery);
    });

    test('coupure réseau : l’écran est en erreur', () {
      server
        ..on(_deliveries, _ok([]))
        ..cutOnce(_rides);
      expect(ActivityApiDataSource(server.client()).fetch(), throwsA(isA<NetworkException>()));
    });
  });

  group('livraisons', () {
    test('statut, titre et montant', () async {
      final server = StubServer()
        ..on(_rides, _ok({'total': 0, 'rides': []}))
        ..on(
          _deliveries,
          _ok([
            _delivery('a', 'IN_TRANSIT', driver: true),
            _delivery('b', 'COMPLETED', finalPrice: 1700),
            _delivery('c', 'CANCELLED'),
            _delivery('d', 'PENDING_MATCH', scheduledAt: '2999-01-01T10:00:00.000Z'),
            _delivery('e', 'PENDING_MATCH'),
          ]),
        );

      final items = await ActivityApiDataSource(server.client()).fetch();

      expect(items.map((a) => a.status), [
        ActivityStatus.ongoing,
        ActivityStatus.done,
        ActivityStatus.cancelled,
        ActivityStatus.upcoming,
        ActivityStatus.ongoing,
      ]);
      expect(items.every((a) => a.service == ServiceType.delivery), isTrue);
      expect(items.first.title, 'Colis vers Fidjrossè');
      expect(items.first.subtitle, 'Coursier : Koffi');
      expect(items[1].amount, 1700);
    });

    test('aucune activité', () async {
      final server = StubServer()
        ..on(_rides, _ok({'total': 0, 'rides': []}))
        ..on(_deliveries, _ok([]));
      expect(await ActivityApiDataSource(server.client()).fetch(), isEmpty);
    });
  });
}

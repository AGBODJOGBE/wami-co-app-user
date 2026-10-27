import 'package:flutter_test/flutter_test.dart';
import 'package:wami/core/domain/service_type.dart';
import 'package:wami/features/activities/data/activity_repository_impl.dart';
import 'package:wami/features/activities/domain/activity.dart';

import '../../support/stub_server.dart';

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

void main() {
  test('livraisons du back : statut, titre et montant', () async {
    final server = StubServer()
      ..on('GET /api/passenger/delivery', {
        'success': true,
        'data': [
          _delivery('a', 'IN_TRANSIT', driver: true),
          _delivery('b', 'COMPLETED', finalPrice: 1700),
          _delivery('c', 'CANCELLED'),
          _delivery('d', 'PENDING_MATCH', scheduledAt: '2999-01-01T10:00:00.000Z'),
          _delivery('e', 'PENDING_MATCH'),
        ],
      });

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
    expect(items.first.amount, 1500);
    expect(items[1].amount, 1700);
  });

  test('aucune livraison', () async {
    final server = StubServer()..on('GET /api/passenger/delivery', {'success': true, 'data': []});
    expect(await ActivityApiDataSource(server.client()).fetch(), isEmpty);
  });
}

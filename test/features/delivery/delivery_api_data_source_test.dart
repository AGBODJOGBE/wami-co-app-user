import 'package:flutter_test/flutter_test.dart';
import 'package:wami/core/auth/auth_session.dart';
import 'package:wami/core/auth/current_session.dart';
import 'package:wami/core/error/exceptions.dart';
import 'package:wami/core/location/location_service.dart';
import 'package:wami/core/location/place_geocoder.dart';
import 'package:wami/core/utils/result.dart';
import 'package:wami/features/delivery/data/datasources/delivery_data_sources.dart';
import 'package:wami/features/delivery/domain/entities/delivery.dart';
import 'package:wami/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:wami/features/delivery/domain/usecases/delivery_usecases.dart';

import '../../support/stub_server.dart';

class _Geocoder implements PlaceGeocoder {
  _Geocoder(this.results);
  final List<GeocodedPlace> results;
  int calls = 0;

  @override
  Future<List<GeocodedPlace>> search(String query) async {
    calls++;
    return results;
  }
}

const _fidjrosse = GeocodedPlace(id: '1', name: 'Fidjrossè', address: 'Cotonou', lat: 6.35, lng: 2.37);

const _session = AuthSession(
  token: 't',
  userId: 'u',
  passengerId: 'p',
  walletId: 'w',
  phone: '+2290197123456',
  firstName: 'Awa',
  lastName: 'Dossou',
);

const _draft = DeliveryDraft(
  dropoffAddress: 'Fidjrossè plage',
  contactName: 'Koffi',
  contactPhone: '01 97 00 00 01',
  size: ParcelSize.medium,
);

Map<String, dynamic> _ok(Map<String, dynamic> data) => {'success': true, 'data': data};

void main() {
  late StubServer server;
  late _Geocoder geocoder;
  late DeliveryApiDataSource delivery;

  setUp(() {
    server = StubServer();
    geocoder = _Geocoder(const [_fidjrosse]);
    delivery = DeliveryApiDataSource(
      server.client(),
      CurrentSession()..set(_session),
      const FixedLocationService(GeoPoint(6.3654, 2.4183)),
      geocoder,
      pollEvery: Duration.zero,
      maxConsecutiveErrors: 3,
    );
  });

  group('devis', () {
    test('un prix par véhicule autorisé pour ce colis', () async {
      server
        ..on(
          'POST /api/passenger/delivery/estimate',
          _ok({
            'estimatedPrice': 2500,
            'estimatedDurationMin': 20,
            'allowedVehicleTypes': ['STANDARD', 'CONFORT', 'VAN'],
          }),
        )
        ..on('POST /api/passenger/delivery/estimate', _ok({'estimatedPrice': 2500, 'estimatedDurationMin': 20}))
        ..on('POST /api/passenger/delivery/estimate', _ok({'estimatedPrice': 4000, 'estimatedDurationMin': 25}));

      final quotes = await delivery.quotes(_draft);

      // CONFORT n'existe pas dans l'app de livraison : seuls voiture et van sont proposés.
      expect(quotes.map((q) => q.vehicle), [DeliveryVehicle.standard, DeliveryVehicle.van]);
      final first = server.requests.first.data as Map<String, dynamic>;
      expect(first['parcelType'], 'MEDIUM_PARCEL');
      expect(first['deliveryType'], 'INSTANT');
      expect(first['dropoffLat'], 6.35);
      // Colis envoyé : départ depuis la position du téléphone.
      expect(first['pickupLat'], 6.3654);
      expect(first.containsKey('preferredVehicleType'), isFalse);
    });

    test('colis fragile : type FRAGILE', () async {
      server.on(
        'POST /api/passenger/delivery/estimate',
        _ok({
          'estimatedPrice': 3000,
          'estimatedDurationMin': 20,
          'allowedVehicleTypes': ['STANDARD'],
        }),
      );
      await delivery.quotes(_draft.copyWith(fragile: true));
      expect((server.requests.first.data as Map<String, dynamic>)['parcelType'], 'FRAGILE');
    });

    test('colis à récupérer : l’adresse saisie est le départ, ma position l’arrivée', () async {
      server.on(
        'POST /api/passenger/delivery/estimate',
        _ok({
          'estimatedPrice': 1000,
          'estimatedDurationMin': 10,
          'allowedVehicleTypes': ['MOTO'],
        }),
      );
      await delivery
          .quotes(_draft.copyWith(mode: DeliveryMode.pickup, pickupAddress: 'Fidjrossè plage', size: ParcelSize.small));
      final body = server.requests.first.data as Map<String, dynamic>;
      expect(body['pickupLat'], 6.35);
      expect(body['dropoffLat'], 6.3654);
    });

    test('adresse introuvable', () {
      geocoder = _Geocoder(const []);
      delivery = DeliveryApiDataSource(
        server.client(),
        CurrentSession()..set(_session),
        const FixedLocationService(),
        geocoder,
      );
      expect(
        () => delivery.quotes(_draft),
        throwsA(isA<BusinessRuleException>().having((e) => e.message, 'message', contains('Adresse introuvable'))),
      );
    });

    test('le véhicule habituel est mis en avant, sinon le moins cher', () async {
      final repo = _QuotesRepo([
        const DeliveryQuote(vehicle: DeliveryVehicle.standard, price: 2500, etaMinutes: 20, suitable: false),
        const DeliveryQuote(vehicle: DeliveryVehicle.van, price: 4000, etaMinutes: 25, suitable: false),
      ]);
      final quotes = (await GetDeliveryQuotes(repo)(_draft.copyWith(size: ParcelSize.large))).valueOrNull!;
      // Grand colis : moto/tricycle ne sont pas proposés par le back, le moins cher est recommandé.
      expect(quotes.first.vehicle, DeliveryVehicle.standard);
      expect(quotes.first.suitable, isTrue);
      expect(quotes.where((q) => q.suitable), hasLength(1));
    });
  });

  group('commande', () {
    test('adresses géocodées une seule fois, contact et paiement', () async {
      server
        ..on(
          'POST /api/passenger/delivery/estimate',
          _ok({
            'estimatedPrice': 2500,
            'estimatedDurationMin': 20,
            'allowedVehicleTypes': ['STANDARD'],
          }),
        )
        ..on('POST /api/passenger/delivery', _ok({'orderId': 'o1'}));
      await delivery.quotes(_draft);

      final id = await delivery.placeOrder(
        _draft.copyWith(vehicle: DeliveryVehicle.standard, cashOnDelivery: true, cashAmount: 15000),
      );

      expect(id, 'o1');
      expect(geocoder.calls, 1);
      final body = server.last('POST /api/passenger/delivery')!.data as Map<String, dynamic>;
      expect(body['recipient'], {'isSelf': false, 'name': 'Koffi', 'phone': '+2290197000001'});
      expect(body['dropoff'], containsPair('latitude', 6.35));
      expect(body['preferredVehicleType'], 'STANDARD');
      expect(body['paymentMethod'], 'WALLET');
      // Transmis mais pas encore gérés par le back.
      expect(body['codAmount'], 15000);
      expect(body['payer'], 'SENDER');
    });

    test('livraison programmée : date envoyée en UTC', () async {
      server.on('POST /api/passenger/delivery', _ok({'orderId': 'o2'}));
      final at = DateTime.utc(2026, 11, 1, 9);
      await delivery.placeOrder(_draft.copyWith(scheduled: true, scheduledAt: at));
      final body = server.last('POST /api/passenger/delivery')!.data as Map<String, dynamic>;
      expect(body['deliveryType'], 'SCHEDULED');
      expect(body['scheduledAt'], '2026-11-01T09:00:00.000Z');
    });
  });

  group('suivi', () {
    Map<String, dynamic> d(String status) => _ok({
          'status': status,
          'driver': {
            'name': 'Koffi',
            'vehicle': {'make': 'Bajaj', 'model': 'Boxer', 'licensePlate': 'AB 1234 RB'},
          },
        });

    test('attente du coursier, puis étapes jusqu’à la remise', () async {
      server
        ..on('GET /api/passenger/delivery/o1', _ok({'status': 'PENDING_MATCH'}))
        ..on('GET /api/passenger/delivery/o1', d('DRIVER_ASSIGNED'))
        ..on('GET /api/passenger/delivery/o1', d('IN_TRANSIT'))
        ..on('GET /api/passenger/delivery/o1', d('COMPLETED'));

      final seen = await delivery.track('o1').toList();

      expect(
        seen.map((t) => t.status),
        [DeliveryStatus.courierAssigned, DeliveryStatus.pickedUp, DeliveryStatus.delivered],
      );
      expect(seen.first.courier.name, 'Koffi');
      expect(seen.first.courier.vehicle, 'Bajaj Boxer');
      expect(seen.last.progress, 1);
      expect(seen.first.handoverCode, isEmpty);
    });

    test('annulation : le flux signale l’interruption', () {
      server
        ..on('GET /api/passenger/delivery/o1', d('DRIVER_ASSIGNED'))
        ..on('GET /api/passenger/delivery/o1', _ok({'status': 'CANCELLED'}));
      expect(delivery.track('o1').toList(), throwsA(isA<DeliveryInterrupted>()));
    });

    test('fermer l’écran arrête le suivi, même sans coursier assigné', () async {
      server.on('GET /api/passenger/delivery/o1', _ok({'status': 'PENDING_MATCH'}));
      final sub = delivery.track('o1').listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      final after = server.count('GET /api/passenger/delivery/o1');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(after, greaterThan(0));
      expect(server.count('GET /api/passenger/delivery/o1'), after);
    });

    test('survit à une coupure réseau', () async {
      server
        ..cutOnce('GET /api/passenger/delivery/o1')
        ..on('GET /api/passenger/delivery/o1', d('COMPLETED'));
      final seen = await delivery.track('o1').toList();
      expect(seen.single.status, DeliveryStatus.delivered);
    });
  });
}

class _QuotesRepo implements DeliveryRepository {
  _QuotesRepo(this.quotes);
  final List<DeliveryQuote> quotes;

  @override
  Future<Result<List<DeliveryQuote>>> getQuotes(DeliveryDraft draft) async => Ok(quotes);

  @override
  Future<Result<String>> placeOrder(DeliveryDraft draft) => throw UnimplementedError();

  @override
  Stream<DeliveryTracking> track(String orderId) => throw UnimplementedError();
}

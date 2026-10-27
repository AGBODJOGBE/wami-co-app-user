import 'dart:async';

import '../../../../core/auth/current_session.dart';
import '../../../../core/data/fake_backend.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/location/place_geocoder.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/phone.dart';
import '../../domain/entities/delivery.dart';

abstract interface class DeliveryRemoteDataSource {
  Future<List<DeliveryQuote>> quotes(DeliveryDraft draft);
  Future<String> placeOrder(DeliveryDraft draft);
  Stream<DeliveryTracking> track(String orderId);
}

/// Routes `/api/passenger/delivery/*` du back wami-co (livraison B2C).
///
/// - Les adresses saisies en texte sont converties en coordonnées par le géocodeur (premier résultat) :
///   un colis envoyé part de la position du téléphone, un colis à récupérer arrive à cette position.
/// - Le back choisit les véhicules autorisés selon le colis ; l'app chiffre chacun d'eux.
/// - L'encaissement à la livraison et « le destinataire paie » ne sont pas gérés par le back : ils sont transmis
///   (`codAmount`, `payer`) mais ignorés tant qu'il ne les accepte pas (docs/BACKEND_A_FAIRE.md).
class DeliveryApiDataSource implements DeliveryRemoteDataSource {
  DeliveryApiDataSource(
    this._api,
    this._session,
    this._location,
    this._geocoder, {
    this.pollEvery = const Duration(seconds: 5),
    this.maxConsecutiveErrors = 5,
  });

  final ApiClient _api;
  final CurrentSession _session;
  final LocationService _location;
  final PlaceGeocoder _geocoder;
  final Duration pollEvery;
  final int maxConsecutiveErrors;

  static const _base = '/api/passenger/delivery';

  /// Adresses déjà géocodées : on ne redemande pas les mêmes coordonnées entre le devis et la commande.
  final _resolved = <String, GeocodedPlace>{};

  @override
  Future<List<DeliveryQuote>> quotes(DeliveryDraft draft) async {
    final route = await _route(draft);
    final first = await _estimate(draft, route, null);
    final allowed = [
      for (final name in (first['allowedVehicleTypes'] as List<dynamic>? ?? const []).cast<String>())
        if (DeliveryVehicle.fromApi(name) case final v?) v,
    ];
    if (allowed.isEmpty) throw const BusinessRuleException('unavailable');

    final priced = await Future.wait([
      for (final v in allowed)
        _estimate(draft, route, v).then<DeliveryQuote?>(
          (j) => DeliveryQuote(
            vehicle: v,
            price: ((j['finalEstimatedPrice'] ?? j['estimatedPrice']) as num).toInt(),
            etaMinutes: (j['estimatedDurationMin'] as num?)?.toInt() ?? 0,
            suitable: false,
          ),
          // Véhicule refusé pour ce colis : on ne le propose pas.
          onError: (Object e) => e is BusinessRuleException ? null : throw e,
        ),
    ]);
    return priced.whereType<DeliveryQuote>().toList();
  }

  Future<Map<String, dynamic>> _estimate(DeliveryDraft d, _Route r, DeliveryVehicle? vehicle) {
    return _api.post(
      '$_base/estimate',
      body: {
        'pickupLat': r.pickup.lat,
        'pickupLng': r.pickup.lng,
        'dropoffLat': r.dropoff.lat,
        'dropoffLng': r.dropoff.lng,
        'parcelType': _parcelType(d),
        'deliveryType': d.scheduled ? 'SCHEDULED' : 'INSTANT',
        if (vehicle != null) 'preferredVehicleType': vehicle.apiName,
      },
    );
  }

  @override
  Future<String> placeOrder(DeliveryDraft d) async {
    final route = await _route(d);
    final me = _session.value!;
    final sending = d.mode == DeliveryMode.send;
    final json = await _api.post(
      _base,
      body: {
        'parcel': {
          'type': _parcelType(d),
          'description': 'Colis ${d.size.label.toLowerCase()}${d.fragile ? ' fragile' : ''}',
          'requiresRefrigeration': false,
        },
        'pickup': {
          'latitude': route.pickup.lat,
          'longitude': route.pickup.lng,
          'address': route.pickup.address,
          // Colis à récupérer : le contact saisi est l'expéditeur.
          if (!sending) 'contactName': d.contactName,
          if (!sending) 'contactPhone': _international(d.contactPhone),
        },
        'dropoff': {
          'latitude': route.dropoff.lat,
          'longitude': route.dropoff.lng,
          'address': route.dropoff.address,
          if (sending) 'contactName': d.contactName,
          if (sending) 'contactPhone': _international(d.contactPhone),
        },
        'recipient': sending
            ? {'isSelf': false, 'name': d.contactName, 'phone': _international(d.contactPhone)}
            : {'isSelf': true, 'name': me.fullName, 'phone': me.phone},
        'paymentMethod': 'WALLET',
        'deliveryType': d.scheduled ? 'SCHEDULED' : 'INSTANT',
        if (d.scheduled && d.scheduledAt != null) 'scheduledAt': d.scheduledAt!.toUtc().toIso8601String(),
        'preferredVehicleType': d.vehicle.apiName,
        // Non gérés par le back pour l'instant : transmis pour le jour où il les acceptera.
        if (d.cashOnDelivery) 'codAmount': d.cashAmount,
        'payer': d.payer == DeliveryPayer.sender ? 'SENDER' : 'RECIPIENT',
      },
    );
    return json['orderId'] as String;
  }

  /// Suivi par interrogation régulière.
  ///
  /// Un `async*` ne détecte l'annulation qu'à un `yield` : tant qu'aucun coursier n'est assigné, rien n'est émis
  /// et la boucle tournerait pour toujours après la fermeture de l'écran. D'où le `StreamController` et son `onCancel`.
  @override
  Stream<DeliveryTracking> track(String orderId) {
    var active = true;
    late final StreamController<DeliveryTracking> controller;

    Future<void> poll() async {
      var errors = 0;
      while (active) {
        try {
          final j = await _api.get('$_base/$orderId');
          errors = 0;
          if (!active) return;
          final status = j['status'] as String?;
          final tracking = DeliveryModels.tracking(orderId, j);
          // En attente d'un coursier : rien à afficher, l'écran montre « Recherche d'un coursier ».
          if (tracking != null) controller.add(tracking);
          final stop = DeliveryModels.interruption(status);
          if (stop != null) {
            controller.addError(DeliveryInterrupted(stop));
            break;
          }
          if (status == 'COMPLETED') break;
        } on NetworkException catch (e) {
          // Tunnel, zone sans réseau : on réessaie sans casser le suivi.
          if (++errors >= maxConsecutiveErrors) {
            controller.addError(e);
            break;
          }
        } on ServerException catch (e) {
          if (++errors >= maxConsecutiveErrors) {
            controller.addError(e);
            break;
          }
        } on Exception catch (e) {
          controller.addError(e);
          break;
        }
        await Future<void>.delayed(pollEvery);
      }
      if (active) await controller.close();
    }

    controller = StreamController<DeliveryTracking>(onListen: poll, onCancel: () => active = false);
    return controller.stream;
  }

  Future<_Route> _route(DeliveryDraft d) async {
    final here = await _location.current();
    final me = GeocodedPlace(id: 'me', name: 'Ma position', address: 'Ma position', lat: here.lat, lng: here.lng);
    final typed = await _geocode(d.mode == DeliveryMode.send ? d.dropoffAddress : d.pickupAddress);
    return d.mode == DeliveryMode.send ? _Route(pickup: me, dropoff: typed) : _Route(pickup: typed, dropoff: me);
  }

  Future<GeocodedPlace> _geocode(String address) async {
    final key = address.trim().toLowerCase();
    final known = _resolved[key];
    if (known != null) return known;
    final found = await _geocoder.search(address.trim());
    if (found.isEmpty) {
      throw const BusinessRuleException('rejected', 'Adresse introuvable. Ajoutez le quartier ou la ville.');
    }
    final place = found.first;
    return _resolved[key] = GeocodedPlace(
      id: place.id,
      name: place.name,
      address: address.trim(),
      lat: place.lat,
      lng: place.lng,
    );
  }

  /// Le colis fragile prime sur sa taille (le back lui impose un véhicule plus protecteur).
  String _parcelType(DeliveryDraft d) {
    if (d.fragile) return 'FRAGILE';
    return switch (d.size) {
      ParcelSize.small => 'SMALL_PARCEL',
      ParcelSize.medium => 'MEDIUM_PARCEL',
      ParcelSize.large => 'LARGE_PARCEL',
    };
  }

  String _international(String raw) => BeninPhone.toInternational(raw) ?? raw.trim();
}

class _Route {
  const _Route({required this.pickup, required this.dropoff});
  final GeocodedPlace pickup;
  final GeocodedPlace dropoff;
}

/// Conversions des réponses du back en entités du suivi de livraison.
abstract final class DeliveryModels {
  /// `null` tant qu'aucun coursier n'est assigné.
  static DeliveryTracking? tracking(String orderId, Map<String, dynamic> j) {
    final status = switch (j['status'] as String?) {
      'DRIVER_ASSIGNED' || 'PICKUP_IN_PROGRESS' => DeliveryStatus.courierAssigned,
      'IN_TRANSIT' => DeliveryStatus.pickedUp,
      'DELIVERY_IN_PROGRESS' => DeliveryStatus.inTransit,
      'COMPLETED' => DeliveryStatus.delivered,
      _ => null,
    };
    if (status == null) return null;
    final driver = j['driver'] as Map<String, dynamic>?;
    final vehicle = driver?['vehicle'] as Map<String, dynamic>?;
    return DeliveryTracking(
      orderId: orderId,
      status: status,
      progress: const {
        DeliveryStatus.courierAssigned: 0.1,
        DeliveryStatus.pickedUp: 0.4,
        DeliveryStatus.inTransit: 0.75,
        DeliveryStatus.delivered: 1.0,
      }[status]!,
      // Le back ne montre pas le code de remise à l'expéditeur : rien n'est affiché.
      handoverCode: '',
      courier: Courier(
        name: driver?['name'] as String? ?? '',
        vehicle: [vehicle?['make'], vehicle?['model']].whereType<String>().where((x) => x.isNotEmpty).join(' '),
        plate: vehicle?['licensePlate'] as String? ?? '',
      ),
    );
  }

  /// Message à montrer quand la livraison ne ira pas à son terme, `null` sinon.
  static String? interruption(String? status) => switch (status) {
        'CANCELLED' => 'La livraison a été annulée.',
        'PICKUP_FAILED' => 'Le coursier n’a pas pu récupérer le colis.',
        'DELIVERY_FAILED' || 'RETURN_IN_PROGRESS' || 'RETURNED' => 'La remise a échoué : le colis vous est retourné.',
        _ => null,
      };
}

class DeliveryFakeDataSource implements DeliveryRemoteDataSource {
  DeliveryFakeDataSource(this._fake, {this.step = const Duration(seconds: 4)});
  final FakeBackend _fake;
  final Duration step;

  @override
  Future<List<DeliveryQuote>> quotes(DeliveryDraft draft) async {
    await _fake.latency();
    // Prix d'exemple, à valider.
    final extra = draft.size == ParcelSize.large ? 500 : 0;
    return [
      DeliveryQuote(vehicle: DeliveryVehicle.moto, price: 1000 + extra, etaMinutes: 35, suitable: false),
      DeliveryQuote(vehicle: DeliveryVehicle.tricycle, price: 1800 + extra, etaMinutes: 50, suitable: false),
    ];
  }

  @override
  Future<String> placeOrder(DeliveryDraft draft) async {
    await _fake.latency();
    return _fake.reference();
  }

  @override
  Stream<DeliveryTracking> track(String orderId) async* {
    const courier = Courier(name: '[Nom du coursier]', vehicle: 'Moto', plate: '[PLAQUE]');
    final eta = DateTime.now().add(const Duration(minutes: 35));
    const progress = [0.0, 0.25, 0.75, 1.0];
    for (final s in DeliveryStatus.values) {
      yield DeliveryTracking(
        orderId: orderId,
        status: s,
        progress: progress[s.index],
        handoverCode: '4821',
        courier: courier,
        eta: eta,
      );
      if (s != DeliveryStatus.delivered) await Future<void>.delayed(step);
    }
  }
}

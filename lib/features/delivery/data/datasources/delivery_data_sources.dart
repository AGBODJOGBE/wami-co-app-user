import '../../../../core/data/fake_backend.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/delivery.dart';

abstract interface class DeliveryRemoteDataSource {
  Future<List<DeliveryQuote>> quotes(DeliveryDraft draft);
  Future<String> placeOrder(DeliveryDraft draft);
  Stream<DeliveryTracking> track(String orderId);
}

Map<String, dynamic> _draftToJson(DeliveryDraft d) => {
      'mode': d.mode.name,
      'pickup': d.pickupAddress,
      'dropoff': d.dropoffAddress,
      'contact': {'name': d.contactName, 'phone': d.contactPhone},
      'scheduled': d.scheduled,
      'size': d.size.name,
      'fragile': d.fragile,
      'cash_on_delivery': d.cashOnDelivery ? d.cashAmount : null,
      'vehicle': d.vehicle.name,
      'payer': d.payer.name,
    };

/// Endpoints à valider avec l'équipe back.
class DeliveryApiDataSource implements DeliveryRemoteDataSource {
  const DeliveryApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<List<DeliveryQuote>> quotes(DeliveryDraft draft) async {
    final json = await _api.post('/v1/deliveries/quote', body: _draftToJson(draft));
    return (json['items'] as List<dynamic>).cast<Map<String, dynamic>>().map((j) {
      return DeliveryQuote(
        vehicle: DeliveryVehicle.values.byName(j['vehicle'] as String),
        price: j['price'] as int,
        etaMinutes: j['eta_minutes'] as int,
        suitable: j['suitable'] as bool? ?? false,
      );
    }).toList();
  }

  @override
  Future<String> placeOrder(DeliveryDraft draft) async =>
      (await _api.post('/v1/deliveries', body: _draftToJson(draft)))['id'] as String;

  @override
  Stream<DeliveryTracking> track(String orderId) async* {
    while (true) {
      final j = await _api.get('/v1/deliveries/$orderId');
      final c = j['courier'] as Map<String, dynamic>;
      final t = DeliveryTracking(
        orderId: orderId,
        status: DeliveryStatus.values.byName(j['status'] as String),
        progress: (j['progress'] as num).toDouble(),
        handoverCode: j['handover_code'] as String,
        courier: Courier(name: c['name'] as String, vehicle: c['vehicle'] as String, plate: c['plate'] as String),
        eta: DateTime.tryParse(j['eta'] as String? ?? ''),
      );
      yield t;
      if (t.status == DeliveryStatus.delivered) return;
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }
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

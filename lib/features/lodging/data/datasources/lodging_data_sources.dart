import '../../../../core/data/fake_backend.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/lodging.dart';

abstract interface class LodgingRemoteDataSource {
  Future<List<Lodging>> search(StaySearch search);
  Future<List<RoomOption>> rooms(String lodgingId);
  Future<Booking> book(Lodging lodging, RoomOption room, StaySearch search, PaymentMethod payment);
  Future<List<VisitSlot>> visitSlots(String apartmentId);
  Future<void> requestVisit(String apartmentId, String slotId);
}

Lodging _lodging(Map<String, dynamic> j) => Lodging(
      id: j['id'] as String,
      type: LodgingType.values.byName(j['type'] as String),
      name: j['name'] as String,
      area: j['area'] as String,
      rating: (j['rating'] as num).toDouble(),
      price: j['price'] as int,
      amenities: (j['amenities'] as List<dynamic>).map((a) => Amenity.values.byName(a as String)).toSet(),
      verified: j['verified'] as bool? ?? false,
    );

List<Map<String, dynamic>> _items(Map<String, dynamic> j) => (j['items'] as List<dynamic>).cast<Map<String, dynamic>>();

/// Endpoints à valider avec l'équipe back.
class LodgingApiDataSource implements LodgingRemoteDataSource {
  const LodgingApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<List<Lodging>> search(StaySearch s) async {
    final json = await _api.get(
      '/v1/stays',
      query: {
        'type': s.type.name,
        'city': s.city,
        'guests': s.guests,
        'nights': s.nights,
        'amenities': s.priorities.map((a) => a.name).join(','),
      },
    );
    return _items(json).map(_lodging).toList();
  }

  @override
  Future<List<RoomOption>> rooms(String id) async => _items(await _api.get('/v1/stays/$id/rooms'))
      .map(
        (j) => RoomOption(
          id: j['id'] as String,
          name: j['name'] as String,
          description: j['description'] as String,
          pricePerNight: j['price_per_night'] as int,
        ),
      )
      .toList();

  @override
  Future<Booking> book(Lodging lodging, RoomOption room, StaySearch s, PaymentMethod payment) async {
    final j = await _api.post(
      '/v1/stays/${lodging.id}/bookings',
      body: {
        'room_id': room.id,
        'nights': s.nights,
        'guests': s.guests,
        'payment': payment.name,
      },
    );
    return Booking(
      reference: j['reference'] as String,
      lodging: lodging,
      room: room,
      nights: s.nights,
      total: j['total'] as int,
    );
  }

  @override
  Future<List<VisitSlot>> visitSlots(String id) async => _items(await _api.get('/v1/stays/$id/visit-slots'))
      .map(
        (j) => VisitSlot(
          id: j['id'] as String,
          day: j['day'] as String,
          time: j['time'] as String,
          available: j['available'] as bool,
        ),
      )
      .toList();

  @override
  Future<void> requestVisit(String id, String slotId) => _api.post('/v1/stays/$id/visits', body: {'slot_id': slotId});
}

class LodgingFakeDataSource implements LodgingRemoteDataSource {
  const LodgingFakeDataSource(this._fake);
  final FakeBackend _fake;

  // Établissements et prix : exemples à valider.
  static const _all = [
    Lodging(
      id: 'h1',
      type: LodgingType.hotel,
      name: '[Hôtel A]',
      area: 'Centre-ville · 0,8 km de la gare',
      rating: 4.7,
      price: 25000,
      amenities: {Amenity.airConditioning, Amenity.wifi, Amenity.generator, Amenity.security},
      verified: true,
    ),
    Lodging(
      id: 'h2',
      type: LodgingType.hotel,
      name: '[Hôtel B]',
      area: 'Quartier calme · 2,1 km',
      rating: 4.4,
      price: 18000,
      amenities: {Amenity.airConditioning, Amenity.parking},
    ),
    Lodging(
      id: 'h3',
      type: LodgingType.hotel,
      name: '[Hôtel C]',
      area: 'Bord de route · 3,5 km',
      rating: 4.1,
      price: 14000,
      amenities: {Amenity.wifi},
    ),
    Lodging(
      id: 'r1',
      type: LodgingType.room,
      name: '[Chambre meublée A]',
      area: 'Chez l’habitant · 1,2 km',
      rating: 4.5,
      price: 9000,
      amenities: {Amenity.airConditioning, Amenity.furnished},
    ),
    Lodging(
      id: 'r2',
      type: LodgingType.room,
      name: '[Chambre B]',
      area: 'Résidence · 2,4 km',
      rating: 4.3,
      price: 7000,
      amenities: {Amenity.wifi, Amenity.security},
    ),
    Lodging(
      id: 'a1',
      type: LodgingType.apartment,
      name: '[Appartement A]',
      area: '2 ch. · salon · Haie Vive',
      rating: 4.6,
      price: 180000,
      amenities: {Amenity.furnished, Amenity.security, Amenity.runningWater},
      verified: true,
    ),
    Lodging(
      id: 'a2',
      type: LodgingType.apartment,
      name: '[Appartement B]',
      area: '1 ch. · salon · Fidjrossè',
      rating: 4.2,
      price: 120000,
      amenities: {Amenity.runningWater, Amenity.parking},
    ),
  ];

  @override
  Future<List<Lodging>> search(StaySearch s) async {
    await _fake.latency();
    return _all.where((l) => l.type == s.type).toList();
  }

  @override
  Future<List<RoomOption>> rooms(String id) async {
    await _fake.latency(0.5);
    final base = _all.firstWhere((l) => l.id == id).price;
    return [
      RoomOption(id: '$id-std', name: 'Standard', description: 'Lit double · ventilée', pricePerNight: base),
      RoomOption(
        id: '$id-sup',
        name: 'Supérieure',
        description: 'Lit double · climatisée',
        pricePerNight: (base * 1.3).round(),
      ),
      RoomOption(
        id: '$id-ste',
        name: 'Suite',
        description: 'Salon privé · climatisée',
        pricePerNight: (base * 1.9).round(),
      ),
    ];
  }

  @override
  Future<Booking> book(Lodging lodging, RoomOption room, StaySearch s, PaymentMethod payment) async {
    await _fake.latency(1.5);
    return Booking(
      reference: _fake.reference(),
      lodging: lodging,
      room: room,
      nights: s.nights,
      total: room.pricePerNight * s.nights,
    );
  }

  @override
  Future<List<VisitSlot>> visitSlots(String id) async {
    await _fake.latency(0.5);
    return const [
      VisitSlot(id: 's1', day: 'Sam.', time: '09:00', available: true),
      VisitSlot(id: 's2', day: 'Sam.', time: '11:00', available: true),
      VisitSlot(id: 's3', day: 'Sam.', time: '16:00', available: false),
      VisitSlot(id: 's4', day: 'Dim.', time: '10:00', available: true),
      VisitSlot(id: 's5', day: 'Dim.', time: '15:00', available: true),
      VisitSlot(id: 's6', day: 'Lun.', time: '17:30', available: true),
    ];
  }

  @override
  Future<void> requestVisit(String id, String slotId) => _fake.latency();
}

import '../../../../core/data/fake_backend.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/intercity.dart';

abstract interface class IntercityRemoteDataSource {
  Future<List<IntercityOffer>> search(IntercityQuery query);
  Future<IntercityBooking> book(IntercityOffer offer, int seats, IntercityPayment payment);
  Future<int> cancel(String bookingId);
}

String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Routes `/api/passenger/offers` et `/api/passenger/bookings` du back wami-co.
///
/// Le back ne donne pas de liste « mes réservations » : l'app garde la réservation en cours de session.
class IntercityApiDataSource implements IntercityRemoteDataSource {
  const IntercityApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<List<IntercityOffer>> search(IntercityQuery q) async {
    final json = await _api.get(
      '/api/passenger/offers',
      query: {
        'originCity': q.from,
        'destinationCity': q.to,
        'date': _date(q.date),
        'minSeats': q.seats,
      },
    );
    return (json['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>().map(offer).toList();
  }

  @override
  Future<IntercityBooking> book(IntercityOffer offer, int seats, IntercityPayment payment) async {
    try {
      final json = await _api.post(
        '/api/passenger/offers/${offer.id}/book',
        body: {'seatsBooked': seats, 'paymentMethod': payment.api},
      );
      return IntercityBooking(
        id: json['bookingId'] as String,
        offer: offer,
        seats: (json['seatsBooked'] as num?)?.toInt() ?? seats,
        total: (json['totalPrice'] as num?)?.toInt() ?? offer.totalFor(seats),
        payment: payment,
        status: IntercityBookingStatus.fromApi(json['status'] as String?),
      );
    } on BusinessRuleException catch (e) {
      throw frenchError(e);
    }
  }

  @override
  Future<int> cancel(String bookingId) async {
    try {
      final json = await _api.delete('/api/passenger/bookings/$bookingId/cancel');
      return (json['refundAmount'] as num?)?.toInt() ?? 0;
    } on BusinessRuleException catch (e) {
      throw frenchError(e);
    }
  }

  static IntercityOffer offer(Map<String, dynamic> j) {
    final origin = j['originLocation'] as Map<String, dynamic>?;
    final destination = j['destinationLocation'] as Map<String, dynamic>?;
    return IntercityOffer(
      // Le back ne renvoie pas toujours l'identifiant : sans lui, l'offre n'est pas réservable.
      id: (j['id'] ?? j['offerId']) as String?,
      number: j['offerNumber'] as String? ?? '',
      vehicle: vehicleLabel(j['vehicleType'] as String?),
      originCity: j['originCity'] as String? ?? '',
      destinationCity: j['destinationCity'] as String? ?? '',
      originAddress: _nonEmpty(origin?['address']),
      destinationAddress: _nonEmpty(destination?['address']),
      departure: DateTime.parse(j['departureTime'] as String).toLocal(),
      arrival: DateTime.tryParse(j['estimatedArrivalTime'] as String? ?? '')?.toLocal(),
      totalSeats: (j['totalSeats'] as num?)?.toInt() ?? 0,
      availableSeats: (j['availableSeats'] as num?)?.toInt() ?? 0,
      pricePerSeat: (j['pricePerSeat'] as num?)?.toInt() ?? 0,
      stops: [
        for (final w in (j['waypoints'] as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>())
          if (_nonEmpty(w['city']) case final city?) city,
      ],
      description: _nonEmpty(j['description']),
    );
  }

  static String? _nonEmpty(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

  static String vehicleLabel(String? api) => switch (api) {
        'MOTO' => 'Moto',
        'STANDARD' => 'Standard',
        'CONFORT' => 'Confort',
        'PREMIUM' => 'Confort',
        'VIP' => 'VIP',
        null || '' => 'Véhicule',
        final other => other[0] + other.substring(1).toLowerCase(),
      };

  /// Le back répond en anglais : on traduit les refus que le passager peut rencontrer.
  static BusinessRuleException frenchError(BusinessRuleException e) {
    final m = (e.message ?? '').toLowerCase();
    BusinessRuleException say(String text) => BusinessRuleException(e.code, text);
    if (m.contains('offer not found')) return say('Ce trajet n’existe plus.');
    if (m.contains('no longer available')) return say('Ce trajet n’est plus disponible.');
    if (m.contains('already have an active booking')) return say('Vous avez déjà réservé sur ce trajet.');
    final seats = RegExp(r'only (\d+) seat').firstMatch(m);
    if (seats != null) return say('Il ne reste que ${seats.group(1)} place(s) sur ce trajet.');
    if (m.contains('insufficient')) return say('Solde insuffisant dans votre portefeuille.');
    if (m.contains('cannot cancel')) return say('Cette réservation ne peut plus être annulée.');
    if (m.contains('booking not found')) return say('Cette réservation est introuvable.');
    return e;
  }
}

/// Trajets simulés pour développer sans back.
class IntercityFakeDataSource implements IntercityRemoteDataSource {
  IntercityFakeDataSource(this._fake);
  final FakeBackend _fake;

  final _cancelled = <String>{};

  @override
  Future<List<IntercityOffer>> search(IntercityQuery q) async {
    await _fake.latency();
    DateTime at(int h, int m) => DateTime(q.date.year, q.date.month, q.date.day, h, m);
    return [
      IntercityOffer(
        id: 'o1',
        number: 'WM-OF-FAKE0001',
        vehicle: 'Confort',
        originCity: q.from,
        destinationCity: q.to,
        originAddress: 'Gare de ${q.from}',
        destinationAddress: 'Gare de ${q.to}',
        departure: at(7, 30),
        arrival: at(12, 30),
        totalSeats: 4,
        availableSeats: 3,
        pricePerSeat: 8000,
        stops: const ['Dassa-Zoumè', 'Savalou'],
        description: 'Climatisé, bagages acceptés.',
      ),
      IntercityOffer(
        id: 'o2',
        number: 'WM-OF-FAKE0002',
        vehicle: 'Standard',
        originCity: q.from,
        destinationCity: q.to,
        departure: at(10, 0),
        arrival: at(16, 0),
        totalSeats: 4,
        availableSeats: 1,
        pricePerSeat: 6500,
      ),
      IntercityOffer(
        id: 'o3',
        number: 'WM-OF-FAKE0003',
        vehicle: 'VIP',
        originCity: q.from,
        destinationCity: q.to,
        departure: at(15, 15),
        arrival: at(20, 0),
        totalSeats: 3,
        availableSeats: 3,
        pricePerSeat: 12000,
        description: 'Berline, départ ponctuel.',
      ),
    ].where((o) => o.availableSeats >= q.seats).toList();
  }

  @override
  Future<IntercityBooking> book(IntercityOffer offer, int seats, IntercityPayment payment) async {
    await _fake.latency(1.2);
    return IntercityBooking(
      id: '${_fake.reference()}-${offer.id}',
      offer: offer,
      seats: seats,
      total: offer.totalFor(seats),
      payment: payment,
    );
  }

  @override
  Future<int> cancel(String bookingId) async {
    await _fake.latency(0.8);
    if (!_cancelled.add(bookingId)) {
      throw const BusinessRuleException('rejected', 'Cette réservation ne peut plus être annulée.');
    }
    return 8000;
  }
}

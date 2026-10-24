import '../../../../core/data/fake_backend.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/bus.dart';

abstract interface class BusRemoteDataSource {
  Future<List<BusTrip>> search(BusSearchQuery query);
  Future<SeatMap> seatMap(String tripId);
  Future<BusTicket> book(BusTrip trip, BusSearchQuery query, List<String> seats);
}

BusTrip _trip(Map<String, dynamic> j) => BusTrip(
      id: j['id'] as String,
      company: j['company'] as String,
      departure: j['departure'] as String,
      arrival: j['arrival'] as String,
      durationMinutes: j['duration_minutes'] as int,
      price: j['price'] as int,
      rating: (j['rating'] as num).toDouble(),
      comfort: BusComfort.values.byName(j['comfort'] as String),
      seatsLeft: j['seats_left'] as int,
      station: j['station'] as String? ?? '',
    );

String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Endpoints à valider (API billetterie / SaaS compagnies).
class BusApiDataSource implements BusRemoteDataSource {
  const BusApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<List<BusTrip>> search(BusSearchQuery q) async {
    final json = await _api.get(
      '/v1/bus/trips',
      query: {
        'from': q.from,
        'to': q.to,
        'date': _date(q.date),
        'passengers': q.passengers,
      },
    );
    return (json['items'] as List<dynamic>).cast<Map<String, dynamic>>().map(_trip).toList();
  }

  @override
  Future<SeatMap> seatMap(String tripId) async {
    final json = await _api.get('/v1/bus/trips/$tripId/seats');
    final rows = (json['rows'] as List<dynamic>).map((row) {
      return (row as List<dynamic>).map((s) {
        if (s == null) return null;
        final m = s as Map<String, dynamic>;
        return Seat(code: m['code'] as String, taken: m['taken'] as bool);
      }).toList();
    }).toList();
    return SeatMap(rows: rows);
  }

  @override
  Future<BusTicket> book(BusTrip trip, BusSearchQuery query, List<String> seats) async {
    final j =
        await _api.post('/v1/bus/bookings', body: {'trip_id': trip.id, 'seats': seats, 'date': _date(query.date)});
    return BusTicket(
      reference: j['reference'] as String,
      trip: trip,
      query: query,
      seats: seats,
      total: j['total'] as int,
      qrPayload: j['qr'] as String,
    );
  }
}

class BusFakeDataSource implements BusRemoteDataSource {
  const BusFakeDataSource(this._fake);
  final FakeBackend _fake;

  static const _taken = {'1A', '1B', '2C', '3A', '3D', '4B', '5C', '5D', '6A', '7B', '7C', '8D', '9A', '9B'};

  @override
  Future<List<BusTrip>> search(BusSearchQuery q) async {
    await _fake.latency();
    // Compagnies, horaires et prix : exemples à valider.
    return const [
      BusTrip(
        id: 'a',
        company: '[Compagnie A]',
        departure: '06:30',
        arrival: '13:00',
        durationMinutes: 390,
        price: 8000,
        rating: 4.6,
        comfort: BusComfort.airConditioned,
        seatsLeft: 12,
      ),
      BusTrip(
        id: 'b',
        company: '[Compagnie B]',
        departure: '07:00',
        arrival: '14:15',
        durationMinutes: 435,
        price: 7000,
        rating: 4.2,
        comfort: BusComfort.standard,
        seatsLeft: 5,
      ),
      BusTrip(
        id: 'c',
        company: '[Compagnie C]',
        departure: '08:00',
        arrival: '14:00',
        durationMinutes: 360,
        price: 9500,
        rating: 4.8,
        comfort: BusComfort.vip,
        seatsLeft: 20,
      ),
      BusTrip(
        id: 'd',
        company: '[Compagnie D]',
        departure: '13:30',
        arrival: '20:30',
        durationMinutes: 420,
        price: 7500,
        rating: 4.4,
        comfort: BusComfort.airConditioned,
        seatsLeft: 9,
      ),
    ];
  }

  @override
  Future<SeatMap> seatMap(String tripId) async {
    await _fake.latency(0.6);
    return SeatMap(
      rows: [
        for (var r = 1; r <= 10; r++)
          [
            for (final c in ['A', 'B', null, 'C', 'D'])
              c == null ? null : Seat(code: '$r$c', taken: _taken.contains('$r$c')),
          ],
      ],
    );
  }

  @override
  Future<BusTicket> book(BusTrip trip, BusSearchQuery query, List<String> seats) async {
    await _fake.latency(1.5);
    final ref = _fake.reference();
    return BusTicket(
      reference: ref,
      trip: trip,
      query: query,
      seats: seats,
      total: trip.price * seats.length,
      qrPayload: 'wami:bus:$ref:${seats.join(',')}',
    );
  }
}

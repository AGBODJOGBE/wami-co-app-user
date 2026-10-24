import 'package:flutter_test/flutter_test.dart';
import 'package:wami/features/bus/domain/entities/bus.dart';
import 'package:wami/features/bus/domain/services/trip_ranking.dart';

void main() {
  const a = BusTrip(
    id: 'a',
    company: 'A',
    departure: '06:30',
    arrival: '13:00',
    durationMinutes: 390,
    price: 8000,
    rating: 4.6,
    comfort: BusComfort.airConditioned,
    seatsLeft: 12,
  );
  const b = BusTrip(
    id: 'b',
    company: 'B',
    departure: '07:00',
    arrival: '14:15',
    durationMinutes: 435,
    price: 7000,
    rating: 4.2,
    comfort: BusComfort.standard,
    seatsLeft: 5,
  );
  const c = BusTrip(
    id: 'c',
    company: 'C',
    departure: '08:00',
    arrival: '14:00',
    durationMinutes: 360,
    price: 9500,
    rating: 4.8,
    comfort: BusComfort.vip,
    seatsLeft: 20,
  );
  const trips = [a, b, c];

  test('tri par prix', () {
    expect(TripRanking.sort(trips, TripSort.price).map((t) => t.id), ['b', 'a', 'c']);
  });

  test('tri par durée', () {
    expect(TripRanking.sort(trips, TripSort.duration).first.id, 'c');
  });

  test('le comparatif repère le meilleur de chaque critère', () {
    final cmp = TripComparison([a, b, c]);
    expect(cmp.cheapest.id, 'b');
    expect(cmp.fastest.id, 'c');
    expect(cmp.bestRated.id, 'c');
    expect(cmp.mostSeats.id, 'c');
    expect(cmp.advice((n) => '$n F'), contains('2500 F'));
  });
}

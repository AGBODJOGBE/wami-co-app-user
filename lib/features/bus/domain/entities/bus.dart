import 'package:equatable/equatable.dart';

class BusSearchQuery extends Equatable {
  const BusSearchQuery({required this.from, required this.to, required this.date, this.passengers = 1});

  final String from;
  final String to;
  final DateTime date;
  final int passengers;

  BusSearchQuery swapped() => BusSearchQuery(from: to, to: from, date: date, passengers: passengers);

  BusSearchQuery copyWith({DateTime? date, int? passengers}) =>
      BusSearchQuery(from: from, to: to, date: date ?? this.date, passengers: passengers ?? this.passengers);

  @override
  List<Object?> get props => [from, to, date, passengers];
}

enum BusComfort {
  standard('Standard'),
  airConditioned('Climatisé'),
  vip('VIP');

  const BusComfort(this.label);
  final String label;
}

class BusTrip extends Equatable {
  const BusTrip({
    required this.id,
    required this.company,
    required this.departure,
    required this.arrival,
    required this.durationMinutes,
    required this.price,
    required this.rating,
    required this.comfort,
    required this.seatsLeft,
    this.station = '[Gare]',
  });

  final String id;
  final String company;

  /// Heures au format « HH:mm » (heure locale de la gare).
  final String departure;
  final String arrival;
  final int durationMinutes;
  final int price;
  final double rating;
  final BusComfort comfort;
  final int seatsLeft;
  final String station;

  @override
  List<Object?> get props =>
      [id, company, departure, arrival, durationMinutes, price, rating, comfort, seatsLeft, station];
}

enum TripSort {
  recommended('Recommandé'),
  price('Prix'),
  departure('Départ'),
  duration('Durée'),
  rating('Note');

  const TripSort(this.label);
  final String label;
}

class Seat extends Equatable {
  const Seat({required this.code, required this.taken});
  final String code;
  final bool taken;

  @override
  List<Object?> get props => [code, taken];
}

/// Plan du bus : rangées de sièges, `null` = allée.
class SeatMap extends Equatable {
  const SeatMap({required this.rows});
  final List<List<Seat?>> rows;

  @override
  List<Object?> get props => [rows];
}

class BusTicket extends Equatable {
  const BusTicket({
    required this.reference,
    required this.trip,
    required this.query,
    required this.seats,
    required this.total,
    required this.qrPayload,
  });

  final String reference;
  final BusTrip trip;
  final BusSearchQuery query;
  final List<String> seats;
  final int total;
  final String qrPayload;

  @override
  List<Object?> get props => [reference, trip, query, seats, total, qrPayload];
}

import 'package:equatable/equatable.dart';

/// Villes proposées d'office dans la recherche. Le back compare le nom de ville tel quel (sans tenir compte de rien d'autre),
/// d'où une liste fermée plutôt qu'une saisie libre.
abstract final class BeninCities {
  static const main = [
    'Cotonou',
    'Abomey-Calavi',
    'Porto-Novo',
    'Ouidah',
    'Lokossa',
    'Bohicon',
    'Abomey',
    'Dassa-Zoumè',
    'Savalou',
    'Parakou',
    'Djougou',
    'Natitingou',
    'Kandi',
  ];
}

class IntercityQuery extends Equatable {
  const IntercityQuery({required this.from, required this.to, required this.date, this.seats = 1});

  final String from;
  final String to;
  final DateTime date;
  final int seats;

  IntercityQuery swapped() => IntercityQuery(from: to, to: from, date: date, seats: seats);

  IntercityQuery copyWith({String? from, String? to, DateTime? date, int? seats}) =>
      IntercityQuery(from: from ?? this.from, to: to ?? this.to, date: date ?? this.date, seats: seats ?? this.seats);

  @override
  List<Object?> get props => [from, to, date, seats];
}

enum IntercityPayment {
  wallet('Portefeuille WAMI', 'Le montant est réservé dans votre portefeuille'),
  cash('Espèces', 'Vous payez le chauffeur au départ');

  const IntercityPayment(this.label, this.hint);
  final String label;
  final String hint;

  String get api => this == wallet ? 'WALLET' : 'CASH';
}

/// Trajet entre deux villes publié par un chauffeur, dont le passager réserve des places.
class IntercityOffer extends Equatable {
  const IntercityOffer({
    required this.number,
    required this.vehicle,
    required this.originCity,
    required this.destinationCity,
    required this.departure,
    required this.totalSeats,
    required this.availableSeats,
    required this.pricePerSeat,
    this.id,
    this.originAddress,
    this.destinationAddress,
    this.arrival,
    this.stops = const [],
    this.description,
  });

  /// Identifiant utilisé pour réserver. `null` quand le back ne le donne pas : l'offre s'affiche mais ne se réserve pas.
  final String? id;
  final String number;
  final String vehicle;
  final String originCity;
  final String destinationCity;
  final String? originAddress;
  final String? destinationAddress;
  final DateTime departure;
  final DateTime? arrival;
  final int totalSeats;
  final int availableSeats;

  /// Prix d'une place, en FCFA entiers.
  final int pricePerSeat;

  /// Villes d'étape entre le départ et l'arrivée.
  final List<String> stops;
  final String? description;

  bool get bookable => id != null && availableSeats > 0;

  Duration? get duration => arrival?.difference(departure);

  int totalFor(int seats) => pricePerSeat * seats;

  @override
  List<Object?> get props => [
        id,
        number,
        vehicle,
        originCity,
        destinationCity,
        originAddress,
        destinationAddress,
        departure,
        arrival,
        totalSeats,
        availableSeats,
        pricePerSeat,
        stops,
        description,
      ];
}

enum IntercityBookingStatus {
  confirmed,
  cancelled,
  other;

  static IntercityBookingStatus fromApi(String? s) => switch (s) {
        'CONFIRMED' => confirmed,
        'CANCELLED_BY_PASSENGER' || 'CANCELLED_BY_DRIVER' || 'CANCELLED' => cancelled,
        _ => other,
      };
}

class IntercityBooking extends Equatable {
  const IntercityBooking({
    required this.id,
    required this.offer,
    required this.seats,
    required this.total,
    required this.payment,
    this.status = IntercityBookingStatus.confirmed,
    this.refund,
  });

  final String id;
  final IntercityOffer offer;
  final int seats;
  final int total;
  final IntercityPayment payment;
  final IntercityBookingStatus status;

  /// Montant rendu après annulation (FCFA).
  final int? refund;

  /// Code court à donner au chauffeur : les 8 premiers caractères de l'identifiant de réservation.
  String get reference => id.length <= 8 ? id.toUpperCase() : id.substring(0, 8).toUpperCase();

  IntercityBooking cancelled(int refund) => IntercityBooking(
        id: id,
        offer: offer,
        seats: seats,
        total: total,
        payment: payment,
        status: IntercityBookingStatus.cancelled,
        refund: refund,
      );

  @override
  List<Object?> get props => [id, offer, seats, total, payment, status, refund];
}

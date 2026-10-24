import 'package:equatable/equatable.dart';

enum LodgingType {
  hotel('Hôtel', 'Hôtels'),
  room('Chambre', 'Chambres'),
  apartment('Appartement', 'Appartements');

  const LodgingType(this.label, this.plural);
  final String label;
  final String plural;

  /// Un appartement se loue au mois et se visite avant ; le reste se réserve à la nuit.
  bool get isMonthly => this == apartment;
}

enum Amenity {
  airConditioning('Clim'),
  wifi('Wi-Fi'),
  generator('Groupe élec.'),
  security('Gardiennage'),
  parking('Parking'),
  furnished('Meublé'),
  runningWater('Eau courante');

  const Amenity(this.label);
  final String label;
}

class StaySearch extends Equatable {
  const StaySearch({
    this.type = LodgingType.hotel,
    this.city = 'Parakou',
    this.nights = 2,
    this.guests = 2,
    this.priorities = const {Amenity.airConditioning},
  });

  final LodgingType type;
  final String city;
  final int nights;
  final int guests;
  final Set<Amenity> priorities;

  StaySearch copyWith({LodgingType? type, String? city, int? nights, int? guests, Set<Amenity>? priorities}) {
    return StaySearch(
      type: type ?? this.type,
      city: city ?? this.city,
      nights: nights ?? this.nights,
      guests: guests ?? this.guests,
      priorities: priorities ?? this.priorities,
    );
  }

  @override
  List<Object?> get props => [type, city, nights, guests, priorities];
}

class Lodging extends Equatable {
  const Lodging({
    required this.id,
    required this.type,
    required this.name,
    required this.area,
    required this.rating,
    required this.price,
    required this.amenities,
    this.verified = false,
  });

  final String id;
  final LodgingType type;
  final String name;
  final String area;
  final double rating;

  /// Prix par nuit (hôtel, chambre) ou par mois (appartement).
  final int price;
  final Set<Amenity> amenities;
  final bool verified;

  String get priceUnit => type.isMonthly ? '/ mois' : '/ nuit';

  @override
  List<Object?> get props => [id, type, name, area, rating, price, amenities, verified];
}

class RoomOption extends Equatable {
  const RoomOption({required this.id, required this.name, required this.description, required this.pricePerNight});
  final String id;
  final String name;
  final String description;
  final int pricePerNight;

  @override
  List<Object?> get props => [id, name, description, pricePerNight];
}

enum PaymentMethod {
  wallet('Portefeuille WAMI', 'Débit immédiat'),
  mobileMoney('Mobile Money', '[Opérateurs à valider]'),
  onSite('Payer à l’arrivée', 'Selon l’établissement');

  const PaymentMethod(this.label, this.hint);
  final String label;
  final String hint;
}

class Booking extends Equatable {
  const Booking({
    required this.reference,
    required this.lodging,
    required this.room,
    required this.nights,
    required this.total,
  });
  final String reference;
  final Lodging lodging;
  final RoomOption room;
  final int nights;
  final int total;

  @override
  List<Object?> get props => [reference, lodging, room, nights, total];
}

class VisitSlot extends Equatable {
  const VisitSlot({required this.id, required this.day, required this.time, required this.available});
  final String id;
  final String day;
  final String time;
  final bool available;

  @override
  List<Object?> get props => [id, day, time, available];
}

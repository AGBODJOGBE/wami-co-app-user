import 'package:equatable/equatable.dart';

enum DeliveryMode { send, pickup }

enum ParcelSize {
  small('Petit', 'Enveloppe, téléphone'),
  medium('Moyen', 'Sac, boîte'),
  large('Grand', 'Carton, appareil');

  const ParcelSize(this.label, this.examples);
  final String label;
  final String examples;
}

enum DeliveryVehicle {
  moto('Moto'),
  tricycle('Tricycle');

  const DeliveryVehicle(this.label);
  final String label;

  /// Règle métier : un grand colis part en tricycle, le reste en moto.
  static DeliveryVehicle recommendedFor(ParcelSize size) =>
      size == ParcelSize.large ? DeliveryVehicle.tricycle : DeliveryVehicle.moto;
}

enum DeliveryPayer { sender, recipient }

/// Brouillon de commande construit écran après écran.
class DeliveryDraft extends Equatable {
  const DeliveryDraft({
    this.mode = DeliveryMode.send,
    this.pickupAddress = '',
    this.dropoffAddress = '',
    this.contactName = '',
    this.contactPhone = '',
    this.scheduled = false,
    this.size = ParcelSize.medium,
    this.fragile = false,
    this.cashOnDelivery = false,
    this.cashAmount = 0,
    this.vehicle = DeliveryVehicle.moto,
    this.payer = DeliveryPayer.sender,
  });

  final DeliveryMode mode;
  final String pickupAddress;
  final String dropoffAddress;
  final String contactName;
  final String contactPhone;
  final bool scheduled;
  final ParcelSize size;
  final bool fragile;
  final bool cashOnDelivery;
  final int cashAmount;
  final DeliveryVehicle vehicle;
  final DeliveryPayer payer;

  /// Le contact saisi est le destinataire (envoi) ou l'expéditeur (récupération).
  String get contactRole => mode == DeliveryMode.send ? 'Destinataire' : 'Expéditeur';

  DeliveryDraft copyWith({
    DeliveryMode? mode,
    String? pickupAddress,
    String? dropoffAddress,
    String? contactName,
    String? contactPhone,
    bool? scheduled,
    ParcelSize? size,
    bool? fragile,
    bool? cashOnDelivery,
    int? cashAmount,
    DeliveryVehicle? vehicle,
    DeliveryPayer? payer,
  }) {
    return DeliveryDraft(
      mode: mode ?? this.mode,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      scheduled: scheduled ?? this.scheduled,
      size: size ?? this.size,
      fragile: fragile ?? this.fragile,
      cashOnDelivery: cashOnDelivery ?? this.cashOnDelivery,
      cashAmount: cashAmount ?? this.cashAmount,
      vehicle: vehicle ?? this.vehicle,
      payer: payer ?? this.payer,
    );
  }

  @override
  List<Object?> get props => [
        mode,
        pickupAddress,
        dropoffAddress,
        contactName,
        contactPhone,
        scheduled,
        size,
        fragile,
        cashOnDelivery,
        cashAmount,
        vehicle,
        payer,
      ];
}

class DeliveryQuote extends Equatable {
  const DeliveryQuote({required this.vehicle, required this.price, required this.etaMinutes, required this.suitable});

  final DeliveryVehicle vehicle;
  final int price;
  final int etaMinutes;

  /// Adapté à la taille du colis.
  final bool suitable;

  @override
  List<Object?> get props => [vehicle, price, etaMinutes, suitable];
}

enum DeliveryStatus {
  courierAssigned('Coursier assigné'),
  pickedUp('Colis récupéré'),
  inTransit('En route vers le destinataire'),
  delivered('Livré');

  const DeliveryStatus(this.label);
  final String label;
}

class Courier extends Equatable {
  const Courier({required this.name, required this.vehicle, required this.plate});
  final String name;
  final String vehicle;
  final String plate;

  @override
  List<Object?> get props => [name, vehicle, plate];
}

class DeliveryTracking extends Equatable {
  const DeliveryTracking({
    required this.orderId,
    required this.status,
    required this.progress,
    required this.handoverCode,
    required this.courier,
    this.eta,
  });

  final String orderId;
  final DeliveryStatus status;
  final double progress;

  /// Code à 4 chiffres envoyé au destinataire, exigé à la remise.
  final String handoverCode;
  final Courier courier;
  final DateTime? eta;

  @override
  List<Object?> get props => [orderId, status, progress, handoverCode, courier, eta];
}

import 'package:equatable/equatable.dart';

class Place extends Equatable {
  const Place({required this.id, required this.name, required this.address, this.lat, this.lng});

  final String id;
  final String name;
  final String address;
  final double? lat;
  final double? lng;

  @override
  List<Object?> get props => [id, name, address, lat, lng];
}

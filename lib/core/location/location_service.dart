import 'package:geolocator/geolocator.dart';

import '../error/exceptions.dart';

/// Coordonnées géographiques.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// Position actuelle du téléphone.
abstract interface class LocationService {
  /// Lève [LocationUnavailableException] si la position ne peut pas être lue.
  Future<GeoPoint> current();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<GeoPoint> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationUnavailableException('Activez la localisation de votre téléphone.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw const LocationUnavailableException('WAMI a besoin de votre position pour trouver un chauffeur.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationUnavailableException('Autorisez la localisation dans les réglages du téléphone.');
    }
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
      );
      return GeoPoint(p.latitude, p.longitude);
    } catch (_) {
      throw const LocationUnavailableException('Position introuvable. Réessayez à l’extérieur ou avec le GPS activé.');
    }
  }
}

/// Faux backend : un point fixe à Cotonou.
class FixedLocationService implements LocationService {
  const FixedLocationService([this.point = const GeoPoint(6.3654, 2.4183)]);
  final GeoPoint point;

  @override
  Future<GeoPoint> current() async => point;
}

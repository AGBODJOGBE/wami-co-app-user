import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/place.dart';

/// Recherche d'adresses. Le back n'a pas (encore) de service de géocodage.
abstract interface class PlaceGeocoder {
  Future<List<Place>> search(String query);
}

/// OpenStreetMap Nominatim, limité au Bénin.
///
/// ⚠️ Le serveur public est réservé à un usage léger (1 requête par seconde, identification de l'application).
/// Pour la production : un service dédié (Google Places, Mapbox, ou Nominatim hébergé) via `WAMI_GEOCODER_URL`.
class NominatimGeocoder implements PlaceGeocoder {
  NominatimGeocoder({String baseUrl = defaultUrl, Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 10),
                // Pas de jeton WAMI ici : c'est un service tiers.
                headers: {'User-Agent': 'WAMI-app/0.1 (contact@wami.bj)', 'Accept-Language': 'fr'},
              ),
            );

  static const defaultUrl = 'https://nominatim.openstreetmap.org';
  final Dio _dio;

  @override
  Future<List<Place>> search(String query) async {
    try {
      final response = await _dio.get<Object?>(
        '/search',
        queryParameters: {'q': query, 'format': 'jsonv2', 'countrycodes': 'bj', 'limit': 6, 'addressdetails': 0},
      );
      final data = response.data;
      if (data is! List<dynamic>) return const [];
      return [
        for (final item in data.cast<Map<String, dynamic>>())
          if (_place(item) case final place?) place,
      ];
    } on DioException {
      throw const NetworkException();
    }
  }

  Place? _place(Map<String, dynamic> j) {
    final lat = double.tryParse('${j['lat']}');
    final lng = double.tryParse('${j['lon']}');
    if (lat == null || lng == null) return null;
    final full = (j['display_name'] as String? ?? '').split(',').map((s) => s.trim()).toList();
    final name = (j['name'] as String?)?.isNotEmpty ?? false ? j['name'] as String : full.first;
    return Place(
      id: '${j['place_id']}',
      name: name,
      address: full.skip(1).take(2).join(', '),
      lat: lat,
      lng: lng,
    );
  }
}

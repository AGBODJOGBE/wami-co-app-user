import '../../../../core/domain/service_type.dart';
import '../../domain/entities/home_feed.dart';

/// Modèles JSON ↔ entités. Format JSON à valider avec l'équipe back.
abstract final class HomeFeedModel {
  static HomeFeed fromJson(Map<String, dynamic> json) {
    return HomeFeed(
      firstName: json['first_name'] as String? ?? '',
      promos: (json['promos'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>().map(_promo).toList(),
      quickDestinations:
          (json['quick_destinations'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>().map(_quick).toList(),
    );
  }

  static PromoBanner _promo(Map<String, dynamic> j) => PromoBanner(
        id: j['id'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String? ?? '',
        ctaLabel: j['cta'] as String? ?? 'Découvrir',
        service: ServiceType.values.byName(j['service'] as String),
      );

  static QuickDestination _quick(Map<String, dynamic> j) => QuickDestination(
        id: j['id'] as String,
        label: j['label'] as String,
        address: j['address'] as String? ?? '',
        kind: QuickDestinationKind.values.byName(j['kind'] as String? ?? 'recent'),
      );
}

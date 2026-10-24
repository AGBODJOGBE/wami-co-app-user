import '../entities/bus.dart';

/// Logique pure de classement et de comparaison des départs (testable sans Flutter).
abstract final class TripRanking {
  /// Score « Recommandé » : note élevée, prix et durée faibles.
  /// Pondérations à valider avec l'équipe produit.
  static double score(BusTrip t) => t.rating * 2 - t.price / 2000 - t.durationMinutes / 120;

  static BusTrip? best(List<BusTrip> trips) {
    if (trips.isEmpty) return null;
    return trips.reduce((a, b) => score(a) >= score(b) ? a : b);
  }

  static List<BusTrip> sort(List<BusTrip> trips, TripSort by) {
    final list = [...trips];
    switch (by) {
      case TripSort.recommended:
        list.sort((a, b) => score(b).compareTo(score(a)));
      case TripSort.price:
        list.sort((a, b) => a.price.compareTo(b.price));
      case TripSort.departure:
        list.sort((a, b) => a.departure.compareTo(b.departure));
      case TripSort.duration:
        list.sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
      case TripSort.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return list;
  }
}

/// Résultat du comparatif : meilleur départ par critère + conseil.
class TripComparison {
  TripComparison(this.trips)
      : assert(trips.length >= 2, 'Il faut au moins deux départs à comparer.'),
        cheapest = trips.reduce((a, b) => a.price <= b.price ? a : b),
        fastest = trips.reduce((a, b) => a.durationMinutes <= b.durationMinutes ? a : b),
        bestRated = trips.reduce((a, b) => a.rating >= b.rating ? a : b),
        mostSeats = trips.reduce((a, b) => a.seatsLeft >= b.seatsLeft ? a : b);

  final List<BusTrip> trips;
  final BusTrip cheapest;
  final BusTrip fastest;
  final BusTrip bestRated;
  final BusTrip mostSeats;

  /// Phrase d'aide à la décision.
  String advice(String Function(int amount) money) {
    if (cheapest.id == fastest.id) {
      return '${cheapest.company} est à la fois le moins cher et le plus rapide.';
    }
    final saving = fastest.price - cheapest.price;
    return '${fastest.company} arrive le plus tôt ; ${cheapest.company} vous fait économiser ${money(saving)} par siège.';
  }
}

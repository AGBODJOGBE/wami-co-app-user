/// Numéros béninois : saisie locale (10 chiffres, ex. `01 97 12 34 56`) → format international attendu par le back.
abstract final class BeninPhone {
  static const countryCode = '+229';
  static const localLength = 10;

  /// Garde les chiffres et retire l'indicatif pays s'il a été tapé.
  static String digits(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('00229')) d = d.substring(5);
    if (d.startsWith('229') && d.length > localLength) d = d.substring(3);
    return d;
  }

  static bool isValid(String raw) => digits(raw).length == localLength;

  /// `+2290197123456`, ou `null` si le numéro est incomplet.
  static String? toInternational(String raw) => isValid(raw) ? '$countryCode${digits(raw)}' : null;

  /// `01 97 12 34 56` à partir de `+2290197123456` (affichage).
  static String display(String international) {
    final d = digits(international);
    if (d.length != localLength) return international;
    return [for (var i = 0; i < d.length; i += 2) d.substring(i, i + 2)].join(' ');
  }
}

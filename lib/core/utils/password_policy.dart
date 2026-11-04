/// Règles de mot de passe du back : 8 caractères, une majuscule, une minuscule, un chiffre.
abstract final class PasswordPolicy {
  static const minLength = 8;

  /// Message d'erreur en français, ou `null` si le mot de passe convient.
  static String? check(String password) {
    if (password.length < minLength) return 'Au moins $minLength caractères.';
    if (!RegExp('[A-Z]').hasMatch(password)) return 'Ajoutez une majuscule.';
    if (!RegExp('[a-z]').hasMatch(password)) return 'Ajoutez une minuscule.';
    if (!RegExp('[0-9]').hasMatch(password)) return 'Ajoutez un chiffre.';
    return null;
  }
}

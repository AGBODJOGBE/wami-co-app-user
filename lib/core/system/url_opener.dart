import 'package:url_launcher/url_launcher.dart';

/// Ouvre une adresse hors de l'application (fiche du magasin d'applications).
abstract interface class UrlOpener {
  /// `false` si rien n'a pu s'ouvrir.
  Future<bool> open(String url);
}

class SystemUrlOpener implements UrlOpener {
  const SystemUrlOpener();

  @override
  Future<bool> open(String url) async {
    final uri = Uri.tryParse(url);
    // Uniquement des adresses web : une adresse venue du serveur ne doit pas lancer une autre application.
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

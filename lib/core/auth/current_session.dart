import 'dart:async';

import 'auth_session.dart';

/// Session en mémoire, lue par le client HTTP et par les sources de données
/// (le portefeuille a besoin de `walletId`). Seul `AuthCubit` l'écrit.
class CurrentSession {
  AuthSession? _session;
  final _expired = StreamController<void>.broadcast();

  AuthSession? get value => _session;
  String? get token => _session?.token;

  /// Identifiant du portefeuille. À n'appeler que connecté.
  String get walletId => _session!.walletId;

  void set(AuthSession? session) => _session = session;

  /// Le serveur a refusé le jeton (401) : l'application doit renvoyer vers la connexion.
  Stream<void> get onExpired => _expired.stream;
  void expire() => _expired.add(null);
}

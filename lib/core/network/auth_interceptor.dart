import 'package:dio/dio.dart';

import '../auth/current_session.dart';

/// Ajoute le jeton d'accès aux requêtes et signale un refus du serveur (401 hors connexion).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._session);
  final CurrentSession _session;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _session.token;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Un 401 avec un jeton envoyé = jeton expiré, révoqué, ou session ouverte sur un autre appareil.
    // Sans jeton (mauvais mot de passe à la connexion), ce n'est pas une expiration.
    final sentToken = err.requestOptions.headers.containsKey('Authorization');
    if (err.response?.statusCode == 401 && sentToken) _session.expire();
    handler.next(err);
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:wami/core/auth/current_session.dart';
import 'package:wami/core/config/app_config.dart';
import 'package:wami/core/network/api_client.dart';
import 'package:wami/core/network/auth_interceptor.dart';

/// Faux serveur HTTP pour tester les sources de données sans réseau.
/// Chaque réponse est enregistrée par `MÉTHODE chemin` (sans la chaîne de requête).
class StubServer implements HttpClientAdapter {
  final _routes = <String, List<(int, Object?)>>{};
  final requests = <RequestOptions>[];

  /// Ajoute une réponse. Plusieurs réponses pour la même route sont rendues dans l'ordre, la dernière se répète.
  void on(String route, Object? body, {int status = 200}) {
    _routes.putIfAbsent(route, () => []).add((status, body));
  }

  /// Simule une coupure réseau sur cette route (une fois, puis les réponses suivantes reprennent).
  void cutOnce(String route) => on(route, null, status: -1);

  RequestOptions? last(String route) {
    for (final r in requests.reversed) {
      if ('${r.method} ${r.path}' == route) return r;
    }
    return null;
  }

  int count(String route) => requests.where((r) => '${r.method} ${r.path}' == route).length;

  ApiClient client({CurrentSession? session}) {
    final dio = Dio(BaseOptions(baseUrl: 'http://stub'))..httpClientAdapter = this;
    return ApiClient(
      const AppConfig(apiBaseUrl: 'http://stub', useFakeBackend: false),
      AuthInterceptor(session ?? CurrentSession()),
      dio: dio,
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final queue = _routes['${options.method} ${options.path}'];
    if (queue == null) {
      return ResponseBody.fromString(jsonEncode({'success': false, 'error': 'route inconnue'}), 404, headers: _json);
    }
    final (status, body) = queue.length > 1 ? queue.removeAt(0) : queue.first;
    if (status == -1) {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    }
    return ResponseBody.fromString(jsonEncode(body), status, headers: _json);
  }

  static const _json = {
    Headers.contentTypeHeader: ['application/json'],
  };

  @override
  void close({bool force = false}) {}
}

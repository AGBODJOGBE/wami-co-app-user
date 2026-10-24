import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../error/exceptions.dart';
import 'auth_interceptor.dart';

/// Client HTTP partagé par toutes les sources de données distantes.
///
/// Le back (wami-co) répond `{ "success": true, "data": … }` ou `{ "success": false, "error": … }`
/// (où `error` est un texte ou un objet `{ code, message }`). Ce client :
/// - rend le contenu de `data` (une liste est rendue sous la clé `items`) ;
/// - rend le corps entier quand il n'y a pas de `data` (ex. `verify-otp`) ;
/// - ne lève que des exceptions de `core/error`.
class ApiClient {
  /// [dio] sert aux tests, pour brancher un faux serveur.
  ApiClient(AppConfig config, AuthInterceptor authInterceptor, {Dio? dio})
      : _dio = (dio ?? Dio(_options(config)))..interceptors.add(authInterceptor);

  static BaseOptions _options(AppConfig config) => BaseOptions(
        baseUrl: config.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json', 'Accept-Language': 'fr'},
      );

  final Dio _dio;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) {
    return _send(() => _dio.get<Object?>(path, queryParameters: query));
  }

  Future<Map<String, dynamic>> post(String path, {Object? body}) {
    return _send(() => _dio.post<Object?>(path, data: body));
  }

  Future<Map<String, dynamic>> put(String path, {Object? body}) {
    return _send(() => _dio.put<Object?>(path, data: body));
  }

  Future<Map<String, dynamic>> patch(String path, {Object? body}) {
    return _send(() => _dio.patch<Object?>(path, data: body));
  }

  Future<Map<String, dynamic>> delete(String path, {Object? body}) {
    return _send(() => _dio.delete<Object?>(path, data: body));
  }

  Future<Map<String, dynamic>> _send(Future<Response<Object?>> Function() request) async {
    try {
      return unwrap((await request()).data);
    } on DioException catch (e) {
      throw mapError(e);
    }
  }

  /// Extrait le contenu utile d'une réponse du back.
  static Map<String, dynamic> unwrap(Object? body) {
    if (body is! Map<String, dynamic>) return <String, dynamic>{};
    if (!body.containsKey('data')) return body;
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is List<dynamic>) return {'items': data};
    return <String, dynamic>{};
  }

  /// Convertit une erreur HTTP en exception de `core/error`.
  static Exception mapError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const NetworkException();
      default:
        final status = e.response?.statusCode;
        final body = e.response?.data;
        final (code, message) = _readError(body);
        if (status == 401) return UnauthorizedException(message);
        if (status != null && status >= 400 && status < 500 && status != 429) {
          return BusinessRuleException(code ?? 'rejected', message);
        }
        return ServerException(statusCode: status, message: status == 429 ? message : null);
    }
  }

  static (String?, String?) _readError(Object? body) {
    if (body is! Map<String, dynamic>) return (null, null);
    final error = body['error'];
    if (error is String) return (body['code'] as String?, error);
    if (error is Map<String, dynamic>) return (error['code'] as String?, error['message'] as String?);
    return (body['code'] as String?, body['message'] as String?);
  }
}

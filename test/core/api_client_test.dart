import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wami/core/error/exceptions.dart';
import 'package:wami/core/network/api_client.dart';

DioException _error(int status, Object? body) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(requestOptions: options, statusCode: status, data: body),
  );
}

void main() {
  group('unwrap', () {
    test('rend le contenu de data', () {
      expect(
        ApiClient.unwrap({
          'success': true,
          'data': {'a': 1},
        }),
        {'a': 1},
      );
    });

    test('une liste est rendue sous items', () {
      expect(
        ApiClient.unwrap({
          'success': true,
          'data': [1, 2],
        }),
        {
          'items': [1, 2],
        },
      );
    });

    test('sans data, rend le corps entier (verify-otp)', () {
      expect(ApiClient.unwrap({'success': true, 'hasAccount': true}), {'success': true, 'hasAccount': true});
    });

    test('corps vide ou inattendu', () {
      expect(ApiClient.unwrap(null), isEmpty);
      expect(ApiClient.unwrap('texte'), isEmpty);
    });
  });

  group('mapError', () {
    test('401 : session refusée', () {
      expect(
        ApiClient.mapError(_error(401, {'success': false, 'error': 'Invalid credentials'})),
        isA<UnauthorizedException>(),
      );
    });

    test('400 avec erreur en texte', () {
      final e = ApiClient.mapError(_error(400, {'success': false, 'error': 'Code invalide'})) as BusinessRuleException;
      expect(e.message, 'Code invalide');
    });

    test('erreur en objet {code, message}', () {
      final e = ApiClient.mapError(
        _error(403, {
          'success': false,
          'error': {'code': 'FORBIDDEN', 'message': 'Interdit'},
        }),
      ) as BusinessRuleException;
      expect(e.code, 'FORBIDDEN');
      expect(e.message, 'Interdit');
    });

    test('500 et 429 : erreur serveur', () {
      expect(ApiClient.mapError(_error(500, null)), isA<ServerException>());
      final tooMany = ApiClient.mapError(_error(429, {'error': 'Too many login attempts'})) as ServerException;
      expect(tooMany.message, contains('Trop de tentatives'));
    });

    test('coupure réseau', () {
      final e = DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError);
      expect(ApiClient.mapError(e), isA<NetworkException>());
    });
  });
}

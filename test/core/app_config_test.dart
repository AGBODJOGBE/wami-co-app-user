import 'package:flutter_test/flutter_test.dart';
import 'package:wami/core/config/app_config.dart';

String _server(String url) => AppConfig(apiBaseUrl: url, useFakeBackend: false).serverUrl;

void main() {
  test('les routes commençant par /api, le /api final est retiré', () {
    expect(_server('http://10.0.2.2:3000/api'), 'http://10.0.2.2:3000');
    expect(_server('http://10.0.2.2:3000/api/'), 'http://10.0.2.2:3000');
  });

  test('une adresse sans /api reste telle quelle', () {
    expect(_server('http://10.0.2.2:3000'), 'http://10.0.2.2:3000');
    expect(_server('http://10.0.2.2:3000/'), 'http://10.0.2.2:3000');
    expect(_server('https://api.wami.bj'), 'https://api.wami.bj');
  });
}

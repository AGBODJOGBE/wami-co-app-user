import '../../../../core/app_info/app_info.dart';
import '../../../../core/data/fake_backend.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/app_version_status.dart';

abstract interface class AppUpdateRemoteDataSource {
  Future<AppVersionStatus> check();
}

/// `GET /api/app-config/check-version` du back wami-co (route publique : elle sert avant la connexion).
///
/// Le back compare lui-même la version envoyée à la dernière version et à la version minimale acceptée.
class AppUpdateApiDataSource implements AppUpdateRemoteDataSource {
  const AppUpdateApiDataSource(this._api, this._info);
  final ApiClient _api;
  final AppInfoSource _info;

  @override
  Future<AppVersionStatus> check() async {
    final info = await _info.read();
    final j = await _api.get(
      '/api/app-config/check-version',
      query: {'appType': 'PASSENGER', 'platform': info.platform, 'currentVersion': info.version},
    );
    return AppVersionStatus(
      currentVersion: j['currentVersion'] as String? ?? info.version,
      latestVersion: j['latestVersion'] as String? ?? info.version,
      updateAvailable: j['updateAvailable'] == true,
      forceUpdate: j['forceUpdate'] == true,
      forceUpdateAfter: DateTime.tryParse(j['forceUpdateAfter'] as String? ?? '')?.toLocal(),
      downloadUrl: j['downloadUrl'] as String? ?? '',
      releaseNotes: j['releaseNotes'] as String? ?? '',
    );
  }
}

/// Faux backend : toujours à jour.
class AppUpdateFakeDataSource implements AppUpdateRemoteDataSource {
  const AppUpdateFakeDataSource(this._fake);
  final FakeBackend _fake;

  @override
  Future<AppVersionStatus> check() async {
    await _fake.latency(0.2);
    return const AppVersionStatus(
      currentVersion: '0.1.0',
      latestVersion: '0.1.0',
      updateAvailable: false,
      forceUpdate: false,
      downloadUrl: '',
    );
  }
}

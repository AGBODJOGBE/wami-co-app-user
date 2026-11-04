import 'dart:io' show Platform;

import 'package:package_info_plus/package_info_plus.dart';

/// Version installée de l'application et plateforme, telles que le back les attend.
class AppInfo {
  const AppInfo({required this.version, required this.platform});

  /// Numéro de version de `pubspec.yaml` sans le numéro de build (`0.1.0`).
  final String version;

  /// `ANDROID` ou `IOS`.
  final String platform;
}

/// Où lire la version installée (remplaçable dans les tests).
abstract interface class AppInfoSource {
  Future<AppInfo> read();
}

class PlatformAppInfoSource implements AppInfoSource {
  const PlatformAppInfoSource();

  @override
  Future<AppInfo> read() async {
    final info = await PackageInfo.fromPlatform();
    return AppInfo(version: info.version, platform: Platform.isIOS ? 'IOS' : 'ANDROID');
  }
}

class FixedAppInfoSource implements AppInfoSource {
  const FixedAppInfoSource([this.info = const AppInfo(version: '0.1.0', platform: 'ANDROID')]);
  final AppInfo info;

  @override
  Future<AppInfo> read() async => info;
}

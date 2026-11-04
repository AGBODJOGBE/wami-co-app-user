import 'package:equatable/equatable.dart';

enum UpdateRequirement {
  /// À jour (ou vérification impossible : on ne bloque jamais l'utilisateur sur une panne).
  none,

  /// Une version plus récente existe : un rappel, que l'on peut repousser.
  optional,

  /// Version trop ancienne : l'application n'est plus utilisable avant la mise à jour.
  required,
}

/// Réponse de `GET /api/app-config/check-version`.
class AppVersionStatus extends Equatable {
  const AppVersionStatus({
    required this.currentVersion,
    required this.latestVersion,
    required this.updateAvailable,
    required this.forceUpdate,
    required this.downloadUrl,
    this.forceUpdateAfter,
    this.releaseNotes = '',
  });

  final String currentVersion;
  final String latestVersion;
  final bool updateAvailable;

  /// Version installée plus ancienne que la version minimale acceptée par le back.
  final bool forceUpdate;

  /// Date à partir de laquelle la mise à jour devient obligatoire, si le back en annonce une.
  final DateTime? forceUpdateAfter;
  final String downloadUrl;
  final String releaseNotes;

  UpdateRequirement requirementAt(DateTime now) {
    if (forceUpdate) return UpdateRequirement.required;
    if (!updateAvailable) return UpdateRequirement.none;
    final deadline = forceUpdateAfter;
    if (deadline != null && !now.isBefore(deadline)) return UpdateRequirement.required;
    return UpdateRequirement.optional;
  }

  @override
  List<Object?> get props => [
        currentVersion,
        latestVersion,
        updateAvailable,
        forceUpdate,
        forceUpdateAfter,
        downloadUrl,
        releaseNotes,
      ];
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/system/url_opener.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/app_version_status.dart';
import '../../domain/usecases/check_app_version.dart';

class UpdateState extends Equatable {
  const UpdateState({
    this.requirement = UpdateRequirement.none,
    this.status,
    this.reminderDismissed = false,
    this.openFailed = false,
  });

  final UpdateRequirement requirement;
  final AppVersionStatus? status;

  /// L'utilisateur a repoussé le rappel facultatif (jusqu'au prochain lancement de l'application).
  final bool reminderDismissed;

  /// La fiche du magasin n'a pas pu s'ouvrir.
  final bool openFailed;

  /// Écran de mise à jour obligatoire à afficher.
  bool get blocking => requirement == UpdateRequirement.required;

  /// Rappel facultatif à proposer.
  bool get reminder => requirement == UpdateRequirement.optional && !reminderDismissed;

  UpdateState copyWith({
    UpdateRequirement? requirement,
    AppVersionStatus? status,
    bool? reminderDismissed,
    bool? openFailed,
  }) {
    return UpdateState(
      requirement: requirement ?? this.requirement,
      status: status ?? this.status,
      reminderDismissed: reminderDismissed ?? this.reminderDismissed,
      openFailed: openFailed ?? false,
    );
  }

  @override
  List<Object?> get props => [requirement, status, reminderDismissed, openFailed];
}

/// Vérifie la version de l'application : au démarrage, puis au retour dans l'application (au plus une fois par
/// [minimumGap]). Une vérification qui échoue ne change rien : on ne bloque jamais l'utilisateur sur une panne.
class UpdateCubit extends Cubit<UpdateState> {
  UpdateCubit(
    this._check,
    this._opener, {
    this.enabled = true,
    this.minimumGap = const Duration(minutes: 30),
    DateTime Function()? clock,
  })  : _now = clock ?? DateTime.now,
        super(const UpdateState());

  final CheckAppVersion _check;
  final UrlOpener _opener;

  /// `false` : aucune vérification (développement, faux backend).
  final bool enabled;
  final Duration minimumGap;
  final DateTime Function() _now;
  DateTime? _lastCheck;

  Future<void> check({bool force = false}) async {
    if (!enabled) return;
    final last = _lastCheck;
    if (!force && last != null && _now().difference(last) < minimumGap) return;
    _lastCheck = _now();
    final r = await _check(const NoParams());
    r.fold(
      (_) {}, // Panne ou réponse inattendue : l'état actuel est conservé.
      (status) => emit(state.copyWith(requirement: status.requirementAt(_now()), status: status)),
    );
  }

  void dismissReminder() => emit(state.copyWith(reminderDismissed: true));

  Future<void> openStore() async {
    final url = state.status?.downloadUrl ?? '';
    final opened = url.isNotEmpty && await _opener.open(url);
    if (!opened) emit(state.copyWith(openFailed: true));
  }
}

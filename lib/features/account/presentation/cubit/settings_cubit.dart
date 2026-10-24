import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/usecases/account_usecases.dart';

class SettingsState extends Equatable {
  const SettingsState({this.settings = const AppSettings()});
  final AppSettings settings;

  @override
  List<Object?> get props => [settings];
}

/// Préférences : global (le thème pilote MaterialApp). Enregistrement optimiste.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._get, this._save) : super(const SettingsState());
  final GetSettings _get;
  final SaveSettings _save;

  Future<void> load() async {
    final r = await _get(const NoParams());
    final s = r.valueOrNull;
    if (s != null) emit(SettingsState(settings: s));
  }

  Future<void> update(AppSettings Function(AppSettings s) change) async {
    final next = change(state.settings);
    emit(SettingsState(settings: next));
    await _save(next);
  }
}

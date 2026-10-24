import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/load_status.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/usecases/account_usecases.dart';

class ProfileState extends Equatable {
  const ProfileState({this.status = LoadStatus.idle, this.profile, this.saveStatus = LoadStatus.idle, this.failure});

  final LoadStatus status;
  final UserProfile? profile;
  final LoadStatus saveStatus;
  final Failure? failure;

  @override
  List<Object?> get props => [status, profile, saveStatus, failure];
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._get, this._update) : super(const ProfileState());
  final GetProfile _get;
  final UpdateProfile _update;

  /// Déconnexion : le profil précédent ne doit pas survivre à l'utilisateur.
  void reset() => emit(const ProfileState());

  Future<void> load() async {
    emit(const ProfileState(status: LoadStatus.loading));
    final r = await _get(const NoParams());
    emit(
      r.fold(
        (f) => ProfileState(status: LoadStatus.failure, failure: f),
        (p) => ProfileState(status: LoadStatus.ready, profile: p),
      ),
    );
  }

  Future<void> save({required String fullName, required String phone, required String email}) async {
    final current = state.profile;
    if (current == null) return;
    emit(ProfileState(status: state.status, profile: current, saveStatus: LoadStatus.loading));
    final r = await _update(current.copyWith(fullName: fullName, phone: phone, email: email));
    emit(
      r.fold(
        (f) => ProfileState(status: state.status, profile: current, saveStatus: LoadStatus.failure, failure: f),
        (p) => ProfileState(status: LoadStatus.ready, profile: p, saveStatus: LoadStatus.ready),
      ),
    );
  }
}

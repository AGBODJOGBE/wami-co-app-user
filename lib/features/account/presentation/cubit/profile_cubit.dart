import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/load_status.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/usecases/account_usecases.dart';

class ProfileState extends Equatable {
  const ProfileState({
    this.status = LoadStatus.idle,
    this.profile,
    this.saveStatus = LoadStatus.idle,
    this.verifyStatus = LoadStatus.idle,
    this.notice,
    this.failure,
  });

  final LoadStatus status;
  final UserProfile? profile;
  final LoadStatus saveStatus;
  final LoadStatus verifyStatus;

  /// Message d'information montré une fois (code envoyé, contact vérifié…).
  final String? notice;
  final Failure? failure;

  ProfileState copyWith({
    LoadStatus? status,
    UserProfile? profile,
    LoadStatus? saveStatus,
    LoadStatus? verifyStatus,
    String? notice,
    Failure? failure,
  }) {
    return ProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      saveStatus: saveStatus ?? this.saveStatus,
      verifyStatus: verifyStatus ?? this.verifyStatus,
      // Comme `failure`, le message n'est conservé que pour l'émission qui le signale.
      notice: notice,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, profile, saveStatus, verifyStatus, notice, failure];
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(
    this._get,
    this._update, {
    required SetGender setGender,
    required SetAddress setAddress,
    required ResendVerification resendVerification,
    required VerifyContact verifyContact,
  })  : _setGender = setGender,
        _setAddress = setAddress,
        _resend = resendVerification,
        _verify = verifyContact,
        super(const ProfileState());
  final GetProfile _get;
  final UpdateProfile _update;
  final SetGender _setGender;
  final SetAddress _setAddress;
  final ResendVerification _resend;
  final VerifyContact _verify;

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

  Future<void> setGender(Gender gender) async {
    final r = await _setGender(gender);
    emit(
      r.fold(
        (f) => state.copyWith(failure: f),
        (p) => state.copyWith(profile: p, notice: 'Civilité enregistrée'),
      ),
    );
  }

  Future<void> setAddress(PostalAddress address) async {
    final r = await _setAddress(address);
    emit(
      r.fold(
        (f) => state.copyWith(failure: f),
        (p) => state.copyWith(profile: p, notice: 'Adresse enregistrée'),
      ),
    );
  }

  /// Renvoie les codes ; le back les envoie par SMS et par e-mail.
  Future<void> resendCodes() async {
    final r = await _resend(const NoParams());
    emit(
      r.fold(
        (f) => state.copyWith(failure: f),
        (_) => state.copyWith(notice: 'Codes envoyés par SMS et par e-mail'),
      ),
    );
  }

  Future<void> verify(VerificationKind kind, String code) async {
    emit(state.copyWith(verifyStatus: LoadStatus.loading));
    final r = await _verify(VerifyParams(kind, code));
    emit(
      r.fold(
        (f) => state.copyWith(verifyStatus: LoadStatus.failure, failure: f),
        (p) => state.copyWith(
          verifyStatus: LoadStatus.ready,
          profile: p,
          notice: kind == VerificationKind.email ? 'E-mail vérifié' : 'Téléphone vérifié',
        ),
      ),
    );
  }
}

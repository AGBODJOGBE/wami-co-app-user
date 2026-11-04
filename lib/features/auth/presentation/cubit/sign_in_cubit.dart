import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/load_status.dart';
import '../../../../core/utils/phone.dart';
import '../../domain/entities/auth_entities.dart';
import '../../domain/usecases/auth_usecases.dart';

/// Étapes du parcours de connexion : numéro → code SMS → mot de passe (compte existant) ou inscription.
enum SignInStep { phone, code, password, register, reset }

class SignInState extends Equatable {
  const SignInState({
    this.step = SignInStep.phone,
    this.phone = '',
    this.status = LoadStatus.idle,
    this.failure,
    this.session,
    this.resendAvailableAt,
    this.notice,
  });

  final SignInStep step;

  /// Numéro au format international.
  final String phone;
  final LoadStatus status;
  final Failure? failure;

  /// Renseignée quand la connexion ou l'inscription a réussi.
  final AuthSession? session;

  /// Heure à partir de laquelle un nouveau code peut être demandé.
  final DateTime? resendAvailableAt;

  /// Information à montrer une fois (ex. « Mot de passe modifié »).
  final String? notice;

  bool get busy => status == LoadStatus.loading;

  SignInState copyWith({
    SignInStep? step,
    String? phone,
    LoadStatus? status,
    Failure? failure,
    AuthSession? session,
    DateTime? resendAvailableAt,
    String? notice,
  }) {
    return SignInState(
      step: step ?? this.step,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      failure: failure,
      session: session ?? this.session,
      resendAvailableAt: resendAvailableAt ?? this.resendAvailableAt,
      notice: notice,
    );
  }

  @override
  List<Object?> get props => [step, phone, status, failure, session, resendAvailableAt, notice];
}

class SignInCubit extends Cubit<SignInState> {
  SignInCubit({
    required SendOtp sendOtp,
    required VerifyOtp verifyOtp,
    required LoginPassenger login,
    required RegisterPassenger register,
    required RequestPasswordReset requestReset,
    required ResetPassword resetPassword,
    this.resendDelay = const Duration(seconds: 60),
    DateTime Function()? clock,
  })  : _sendOtp = sendOtp,
        _verifyOtp = verifyOtp,
        _login = login,
        _register = register,
        _requestReset = requestReset,
        _resetPassword = resetPassword,
        _now = clock ?? DateTime.now,
        super(const SignInState());

  final SendOtp _sendOtp;
  final VerifyOtp _verifyOtp;
  final LoginPassenger _login;
  final RegisterPassenger _register;
  final RequestPasswordReset _requestReset;
  final ResetPassword _resetPassword;
  final Duration resendDelay;
  final DateTime Function() _now;

  Future<void> submitPhone(String rawPhone) async {
    final phone = BeninPhone.toInternational(rawPhone);
    if (phone == null) {
      emit(state.copyWith(failure: const ValidationFailure('Saisissez les 10 chiffres de votre numéro.')));
      return;
    }
    await _requestCode(phone, SignInStep.code);
  }

  /// Nouveau code, sans quitter l'étape de saisie du code.
  Future<void> resendCode() async {
    final at = state.resendAvailableAt;
    if (at != null && _now().isBefore(at)) return;
    await _requestCode(state.phone, SignInStep.code);
  }

  Future<void> _requestCode(String phone, SignInStep next) async {
    emit(state.copyWith(phone: phone, status: LoadStatus.loading));
    final r = await _sendOtp(phone);
    emit(
      r.fold(
        (f) => state.copyWith(status: LoadStatus.failure, failure: f),
        (_) => state.copyWith(step: next, status: LoadStatus.ready, resendAvailableAt: _now().add(resendDelay)),
      ),
    );
  }

  Future<void> submitCode(String code) async {
    emit(state.copyWith(status: LoadStatus.loading));
    final r = await _verifyOtp(VerifyOtpParams(phone: state.phone, code: code.trim()));
    emit(
      r.fold(
        (f) => state.copyWith(status: LoadStatus.failure, failure: f),
        (check) => state.copyWith(
          step: check.hasPassengerAccount ? SignInStep.password : SignInStep.register,
          status: LoadStatus.ready,
        ),
      ),
    );
  }

  Future<void> submitPassword(String password) async {
    emit(state.copyWith(status: LoadStatus.loading));
    final r = await _login(LoginParams(phone: state.phone, password: password));
    emit(
      r.fold(
        (f) => state.copyWith(status: LoadStatus.failure, failure: f),
        (s) => state.copyWith(status: LoadStatus.ready, session: s),
      ),
    );
  }

  Future<void> submitRegistration({
    required String firstName,
    required String lastName,
    required String password,
    required Gender gender,
    String? email,
    String? referralCode,
  }) async {
    emit(state.copyWith(status: LoadStatus.loading));
    final r = await _register(
      RegisterData(
        phone: state.phone,
        firstName: firstName,
        lastName: lastName,
        password: password,
        gender: gender,
        email: email,
        referralCode: referralCode,
      ),
    );
    emit(
      r.fold(
        (f) => state.copyWith(status: LoadStatus.failure, failure: f),
        (s) => state.copyWith(status: LoadStatus.ready, session: s),
      ),
    );
  }

  /// « Mot de passe oublié » : un code part par SMS, puis on choisit un nouveau mot de passe.
  Future<void> forgotPassword() async {
    final at = state.resendAvailableAt;
    // Pas de nouvelle demande tant que le délai du dernier envoi n'est pas écoulé (le back limite aussi).
    final reuse = state.step == SignInStep.reset && at != null && _now().isBefore(at);
    if (reuse) return;
    emit(state.copyWith(status: LoadStatus.loading));
    final r = await _requestReset(state.phone);
    emit(
      r.fold(
        (f) => state.copyWith(status: LoadStatus.failure, failure: f),
        (_) => state.copyWith(
          step: SignInStep.reset,
          status: LoadStatus.ready,
          resendAvailableAt: _now().add(resendDelay),
        ),
      ),
    );
  }

  Future<void> submitReset({required String code, required String newPassword}) async {
    emit(state.copyWith(status: LoadStatus.loading));
    final r =
        await _resetPassword(ResetPasswordParams(phone: state.phone, code: code.trim(), newPassword: newPassword));
    emit(
      r.fold(
        (f) => state.copyWith(status: LoadStatus.failure, failure: f),
        (_) => state.copyWith(
          step: SignInStep.password,
          status: LoadStatus.ready,
          notice: 'Mot de passe modifié. Connectez-vous avec le nouveau.',
        ),
      ),
    );
  }

  /// Retour à la saisie du numéro (« Ce n'est pas mon numéro »).
  void changePhone() => emit(const SignInState());
}

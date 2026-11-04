import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/load_status.dart';
import '../../domain/usecases/account_usecases.dart';

class SecurityState extends Equatable {
  const SecurityState({this.status = LoadStatus.idle, this.failure});
  final LoadStatus status;
  final Failure? failure;

  bool get busy => status == LoadStatus.loading;

  @override
  List<Object?> get props => [status, failure];
}

/// Sécurité du compte : changement de mot de passe et suppression.
class SecurityCubit extends Cubit<SecurityState> {
  SecurityCubit(this._changePassword, this._deleteAccount) : super(const SecurityState());
  final ChangePassword _changePassword;
  final DeleteAccount _deleteAccount;

  Future<void> changePassword({required String current, required String next, required String confirmation}) async {
    emit(const SecurityState(status: LoadStatus.loading));
    final r = await _changePassword(ChangePasswordParams(current: current, next: next, confirmation: confirmation));
    emit(
      r.fold(
        (f) => SecurityState(status: LoadStatus.failure, failure: f),
        (_) => const SecurityState(status: LoadStatus.ready),
      ),
    );
  }

  Future<void> deleteAccount(String password) async {
    emit(const SecurityState(status: LoadStatus.loading));
    final r = await _deleteAccount(password);
    emit(
      r.fold(
        (f) => SecurityState(status: LoadStatus.failure, failure: f),
        (_) => const SecurityState(status: LoadStatus.ready),
      ),
    );
  }
}

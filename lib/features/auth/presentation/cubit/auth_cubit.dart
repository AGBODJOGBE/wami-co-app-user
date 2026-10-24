import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/current_session.dart';
import '../../domain/usecases/auth_usecases.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState extends Equatable {
  const AuthState({this.status = AuthStatus.unknown, this.session, this.expired = false});

  final AuthStatus status;
  final AuthSession? session;

  /// La dernière déconnexion vient d'un jeton refusé par le serveur (pas d'un choix de l'utilisateur).
  final bool expired;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  @override
  List<Object?> get props => [status, session, expired];
}

/// Session de l'utilisateur, globale à l'application. C'est le seul écrivain de [CurrentSession].
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({required CurrentSession current, required RestoreSession restore, required SignOut signOut})
      : _current = current,
        _restore = restore,
        _signOut = signOut,
        super(const AuthState()) {
    _expiredSub = _current.onExpired.listen((_) => endSession(expired: true));
  }

  final CurrentSession _current;
  final RestoreSession _restore;
  final SignOut _signOut;
  late final StreamSubscription<void> _expiredSub;

  /// À appeler avant `runApp` : reprend la session de l'appareil.
  Future<void> restore() async {
    final session = await _restore();
    _current.set(session);
    emit(
      session == null
          ? const AuthState(status: AuthStatus.unauthenticated)
          : AuthState(status: AuthStatus.authenticated, session: session),
    );
  }

  void signedIn(AuthSession session) {
    _current.set(session);
    emit(AuthState(status: AuthStatus.authenticated, session: session));
  }

  Future<void> endSession({bool expired = false}) async {
    if (!state.isAuthenticated) return;
    _current.set(null);
    await _signOut();
    emit(AuthState(status: AuthStatus.unauthenticated, expired: expired));
  }

  Future<void> logout() => endSession();

  @override
  Future<void> close() {
    _expiredSub.cancel();
    return super.close();
  }
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/load_status.dart';
import '../../domain/entities/referral.dart';
import '../../domain/usecases/referral_usecases.dart';

class ReferralState extends Equatable {
  const ReferralState({
    this.status = LoadStatus.idle,
    this.overview,
    this.applyStatus = LoadStatus.idle,
    this.failure,
    this.applied,
  });

  final LoadStatus status;
  final ReferralOverview? overview;
  final LoadStatus applyStatus;

  /// Échec à montrer une fois (chargement ou code refusé).
  final Failure? failure;

  /// Parrainage qui vient d'être créé avec le code saisi.
  final IncomingReferral? applied;

  ReferralState copyWith({
    LoadStatus? status,
    ReferralOverview? overview,
    LoadStatus? applyStatus,
    Failure? failure,
    IncomingReferral? applied,
  }) {
    return ReferralState(
      status: status ?? this.status,
      overview: overview ?? this.overview,
      applyStatus: applyStatus ?? this.applyStatus,
      failure: failure,
      applied: applied ?? this.applied,
    );
  }

  @override
  List<Object?> get props => [status, overview, applyStatus, failure, applied];
}

/// Parrainer un proche et utiliser le code d'un proche.
class ReferralCubit extends Cubit<ReferralState> {
  ReferralCubit(this._overview, this._apply) : super(const ReferralState());
  final GetReferralOverview _overview;
  final ApplyReferralCode _apply;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading));
    final r = await _overview(const NoParams());
    emit(
      r.fold(
        (f) => state.copyWith(status: LoadStatus.failure, failure: f),
        (o) => state.copyWith(status: LoadStatus.ready, overview: o),
      ),
    );
  }

  Future<void> apply(String code) async {
    emit(state.copyWith(applyStatus: LoadStatus.loading));
    final r = await _apply(code);
    await r.fold(
      (f) async => emit(state.copyWith(applyStatus: LoadStatus.failure, failure: f)),
      (incoming) async {
        emit(state.copyWith(applyStatus: LoadStatus.ready, applied: incoming));
        // Le parrainage en cours remplace la saisie du code.
        await load();
      },
    );
  }
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/load_status.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/usecases/wallet_usecases.dart';

// ─── Événements ──────────────────────────────────────────────────────────────

sealed class WalletEvent extends Equatable {
  const WalletEvent();
  @override
  List<Object?> get props => [];
}

final class WalletStarted extends WalletEvent {
  const WalletStarted();
}

/// Déconnexion : remet le portefeuille à zéro pour le prochain utilisateur.
final class WalletCleared extends WalletEvent {
  const WalletCleared();
}

final class WalletBalanceVisibilityToggled extends WalletEvent {
  const WalletBalanceVisibilityToggled();
}

/// Charge les sources de recharge et les bénéficiaires (formulaires).
final class WalletFormDataRequested extends WalletEvent {
  const WalletFormDataRequested();
}

final class WalletTopUpRequested extends WalletEvent {
  const WalletTopUpRequested({required this.amount, required this.sourceId});
  final int amount;
  final String sourceId;
  @override
  List<Object?> get props => [amount, sourceId];
}

final class WalletTransferRequested extends WalletEvent {
  const WalletTransferRequested({required this.beneficiary, required this.amount, this.note});
  final Beneficiary beneficiary;
  final int amount;
  final String? note;
  @override
  List<Object?> get props => [beneficiary, amount, note];
}

// ─── État ────────────────────────────────────────────────────────────────────

enum WalletOperationKind { topUp, transfer }

class WalletOperation extends Equatable {
  const WalletOperation({required this.kind, required this.amount, this.counterpart});
  final WalletOperationKind kind;
  final int amount;
  final String? counterpart;
  @override
  List<Object?> get props => [kind, amount, counterpart];
}

class WalletState extends Equatable {
  const WalletState({
    this.status = LoadStatus.idle,
    this.overview,
    this.balanceHidden = false,
    this.sources = const [],
    this.beneficiaries = const [],
    this.operationStatus = LoadStatus.idle,
    this.lastOperation,
    this.failure,
  });

  final LoadStatus status;
  final WalletOverview? overview;
  final bool balanceHidden;
  final List<TopUpSource> sources;
  final List<Beneficiary> beneficiaries;
  final LoadStatus operationStatus;
  final WalletOperation? lastOperation;
  final Failure? failure;

  int get balance => overview?.wallet.balance ?? 0;

  WalletState copyWith({
    LoadStatus? status,
    WalletOverview? overview,
    bool? balanceHidden,
    List<TopUpSource>? sources,
    List<Beneficiary>? beneficiaries,
    LoadStatus? operationStatus,
    WalletOperation? lastOperation,
    Failure? failure,
  }) {
    return WalletState(
      status: status ?? this.status,
      overview: overview ?? this.overview,
      balanceHidden: balanceHidden ?? this.balanceHidden,
      sources: sources ?? this.sources,
      beneficiaries: beneficiaries ?? this.beneficiaries,
      operationStatus: operationStatus ?? this.operationStatus,
      lastOperation: lastOperation ?? this.lastOperation,
      failure: failure,
    );
  }

  @override
  List<Object?> get props =>
      [status, overview, balanceHidden, sources, beneficiaries, operationStatus, lastOperation, failure];
}

// ─── Bloc ────────────────────────────────────────────────────────────────────

/// Portefeuille : bloc global (le solde sert aussi aux paiements des autres services).
class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc({
    required GetWalletOverview getOverview,
    required GetTopUpSources getSources,
    required GetBeneficiaries getBeneficiaries,
    required TopUpWallet topUp,
    required TransferMoney transfer,
  })  : _getOverview = getOverview,
        _getSources = getSources,
        _getBeneficiaries = getBeneficiaries,
        _topUp = topUp,
        _transfer = transfer,
        super(const WalletState()) {
    on<WalletStarted>(_onStarted);
    on<WalletCleared>((e, emit) => emit(const WalletState()));
    on<WalletBalanceVisibilityToggled>((e, emit) => emit(state.copyWith(balanceHidden: !state.balanceHidden)));
    on<WalletFormDataRequested>(_onFormData);
    on<WalletTopUpRequested>(_onTopUp);
    on<WalletTransferRequested>(_onTransfer);
  }

  final GetWalletOverview _getOverview;
  final GetTopUpSources _getSources;
  final GetBeneficiaries _getBeneficiaries;
  final TopUpWallet _topUp;
  final TransferMoney _transfer;

  Future<void> _onStarted(WalletStarted e, Emitter<WalletState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    final r = await _getOverview(const NoParams());
    emit(
      r.fold(
        (f) => state.copyWith(status: LoadStatus.failure, failure: f),
        (o) => state.copyWith(status: LoadStatus.ready, overview: o),
      ),
    );
  }

  Future<void> _onFormData(WalletFormDataRequested e, Emitter<WalletState> emit) async {
    if (state.sources.isNotEmpty && state.beneficiaries.isNotEmpty) return;
    final sources = await _getSources(const NoParams());
    final people = await _getBeneficiaries(const NoParams());
    emit(state.copyWith(sources: sources.valueOrNull, beneficiaries: people.valueOrNull));
  }

  Future<void> _onTopUp(WalletTopUpRequested e, Emitter<WalletState> emit) async {
    emit(state.copyWith(operationStatus: LoadStatus.loading));
    final r = await _topUp(TopUpParams(amount: e.amount, sourceId: e.sourceId));
    emit(
      r.fold(
        (f) => state.copyWith(operationStatus: LoadStatus.failure, failure: f),
        (o) => state.copyWith(
          operationStatus: LoadStatus.ready,
          overview: o,
          lastOperation: WalletOperation(kind: WalletOperationKind.topUp, amount: e.amount),
        ),
      ),
    );
  }

  Future<void> _onTransfer(WalletTransferRequested e, Emitter<WalletState> emit) async {
    emit(state.copyWith(operationStatus: LoadStatus.loading));
    final r = await _transfer(
      TransferParams(
        beneficiaryId: e.beneficiary.id,
        amount: e.amount,
        currentBalance: state.balance,
        note: e.note,
      ),
    );
    emit(
      r.fold(
        (f) => state.copyWith(operationStatus: LoadStatus.failure, failure: f),
        (o) => state.copyWith(
          operationStatus: LoadStatus.ready,
          overview: o,
          lastOperation:
              WalletOperation(kind: WalletOperationKind.transfer, amount: e.amount, counterpart: e.beneficiary.name),
        ),
      ),
    );
  }
}

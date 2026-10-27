import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/load_status.dart';
import '../../domain/entities/delivery.dart';
import '../../domain/usecases/delivery_usecases.dart';

class DeliveryState extends Equatable {
  const DeliveryState({
    this.draft = const DeliveryDraft(),
    this.quotesStatus = LoadStatus.idle,
    this.quotes = const [],
    this.orderStatus = LoadStatus.idle,
    this.tracking,
    this.failure,
  });

  final DeliveryDraft draft;
  final LoadStatus quotesStatus;
  final List<DeliveryQuote> quotes;
  final LoadStatus orderStatus;
  final DeliveryTracking? tracking;
  final Failure? failure;

  DeliveryQuote? get selectedQuote {
    for (final q in quotes) {
      if (q.vehicle == draft.vehicle) return q;
    }
    return null;
  }

  DeliveryState copyWith({
    DeliveryDraft? draft,
    LoadStatus? quotesStatus,
    List<DeliveryQuote>? quotes,
    LoadStatus? orderStatus,
    DeliveryTracking? tracking,
    Failure? failure,
  }) {
    return DeliveryState(
      draft: draft ?? this.draft,
      quotesStatus: quotesStatus ?? this.quotesStatus,
      quotes: quotes ?? this.quotes,
      orderStatus: orderStatus ?? this.orderStatus,
      tracking: tracking ?? this.tracking,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [draft, quotesStatus, quotes, orderStatus, tracking, failure];
}

/// Parcours Livraison : adresses → colis → devis → suivi.
class DeliveryCubit extends Cubit<DeliveryState> {
  DeliveryCubit({
    required ValidateDeliveryAddresses validate,
    required GetDeliveryQuotes getQuotes,
    required PlaceDeliveryOrder placeOrder,
    required TrackDelivery track,
  })  : _validate = validate,
        _getQuotes = getQuotes,
        _placeOrder = placeOrder,
        _track = track,
        super(const DeliveryState());

  final ValidateDeliveryAddresses _validate;
  final GetDeliveryQuotes _getQuotes;
  final PlaceDeliveryOrder _placeOrder;
  final TrackDelivery _track;
  StreamSubscription<DeliveryTracking>? _sub;

  void update(DeliveryDraft Function(DeliveryDraft d) change) => emit(state.copyWith(draft: change(state.draft)));

  void setSize(ParcelSize size) => update(
        (d) => d.copyWith(size: size, vehicle: DeliveryVehicle.recommendedFor(size)),
      );

  /// Valide l'étape adresses. Renvoie `true` si on peut continuer.
  bool submitAddresses() {
    final failure = _validate(state.draft);
    if (failure != null) {
      emit(state.copyWith(failure: failure));
      return false;
    }
    return true;
  }

  Future<void> loadQuotes() async {
    emit(state.copyWith(quotesStatus: LoadStatus.loading));
    final result = await _getQuotes(state.draft);
    result.fold(
      (f) => emit(state.copyWith(quotesStatus: LoadStatus.failure, failure: f)),
      (quotes) => emit(
        state.copyWith(
          quotesStatus: LoadStatus.ready,
          quotes: quotes,
          draft:
              state.draft.copyWith(vehicle: quotes.firstWhere((q) => q.suitable, orElse: () => quotes.first).vehicle),
        ),
      ),
    );
  }

  Future<void> confirm() async {
    emit(state.copyWith(orderStatus: LoadStatus.loading));
    final result = await _placeOrder(state.draft);
    final id = result.valueOrNull;
    if (id == null) {
      emit(state.copyWith(orderStatus: LoadStatus.failure, failure: result.fold((f) => f, (_) => null)));
      return;
    }
    emit(state.copyWith(orderStatus: LoadStatus.ready));
    await _sub?.cancel();
    _sub = _track(id).listen(
      (t) => emit(state.copyWith(tracking: t)),
      // Livraison annulée ou interrompue : l'écran de suivi prévient et ramène à l'accueil.
      onError: (Object e) => emit(
        state.copyWith(
          failure: e is DeliveryInterrupted ? ValidationFailure(e.message) : const NetworkFailure(),
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

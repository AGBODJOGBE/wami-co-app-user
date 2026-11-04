import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/load_status.dart';
import '../../domain/entities/place.dart';
import '../../domain/entities/promo_usage.dart';
import '../../domain/entities/ride.dart';
import '../../domain/entities/vehicle_offer.dart';
import '../../domain/entities/waiting_policy.dart';
import '../../domain/usecases/mobility_usecases.dart';

part 'ride_event.dart';
part 'ride_state.dart';

/// Pilote tout le parcours Mobilité, de la destination au paiement.
class RideBloc extends Bloc<RideEvent, RideState> {
  RideBloc({
    required SearchPlaces searchPlaces,
    required EstimateRideOffers estimateOffers,
    required GetCurrentPlace getCurrentPlace,
    required GetAvailablePromos getAvailablePromos,
    required GetWaitingPolicy getWaitingPolicy,
    required RequestRide requestRide,
    required WatchRide watchRide,
    required CancelRide cancelRide,
    required RateRide rateRide,
    required ChangeRideDestination changeDestination,
    required SetPaymentSplit setPaymentSplit,
    required GetPromoHistory getPromoHistory,
  })  : _getCurrentPlace = getCurrentPlace,
        _getAvailablePromos = getAvailablePromos,
        _searchPlaces = searchPlaces,
        _estimateOffers = estimateOffers,
        _getWaitingPolicy = getWaitingPolicy,
        _requestRide = requestRide,
        _watchRide = watchRide,
        _cancelRide = cancelRide,
        _rateRide = rateRide,
        _changeDestination = changeDestination,
        _setPaymentSplit = setPaymentSplit,
        _getPromoHistory = getPromoHistory,
        super(const RideState()) {
    on<RideStarted>(_onStarted);
    on<RideQueryChanged>(_onQueryChanged);
    on<RideDestinationChosen>(_onDestinationChosen);
    on<RideCategorySelected>((e, emit) => emit(state.copyWith(selected: e.category)));
    on<RidePromoApplied>((e, emit) => _estimate(emit, promoCode: e.code.trim().toUpperCase()));
    on<RidePromoRemoved>((e, emit) => _estimate(emit, clearPromo: true));
    on<RideBooked>(_onBooked);
    on<RideCancelled>(_onCancelled);
    on<RideRated>(_onRated);
    on<RideDestinationChangeRequested>(_onDestinationChange);
    on<RidePaymentSplitSet>(_onPaymentSplit);
    on<RidePromoHistoryRequested>(_onPromoHistory);
  }

  final GetCurrentPlace _getCurrentPlace;
  final GetAvailablePromos _getAvailablePromos;
  final SearchPlaces _searchPlaces;
  final EstimateRideOffers _estimateOffers;
  final GetWaitingPolicy _getWaitingPolicy;
  final RequestRide _requestRide;
  final WatchRide _watchRide;
  final CancelRide _cancelRide;
  final RateRide _rateRide;
  final ChangeRideDestination _changeDestination;
  final SetPaymentSplit _setPaymentSplit;
  final GetPromoHistory _getPromoHistory;

  static const _typingPause = Duration(milliseconds: 350);

  /// Départ en attendant la position du téléphone (sans coordonnées : pas de course possible).
  static const currentPosition = Place(id: 'me', name: 'Ma position', address: 'Position actuelle');

  Future<void> _onStarted(RideStarted e, Emitter<RideState> emit) async {
    final policy = await _getWaitingPolicy(const NoParams());
    emit(state.copyWith(policy: policy.valueOrNull ?? const WaitingPolicy()));
    if (e.initialQuery != null) add(RideQueryChanged(e.initialQuery!));
    await _locate(emit);
    final promos = await _getAvailablePromos(const NoParams());
    emit(state.copyWith(availablePromos: promos.valueOrNull ?? const []));
  }

  /// Lit la position du téléphone ; en cas d'échec, l'erreur est montrée au choix de la destination.
  Future<Failure?> _locate(Emitter<RideState> emit) async {
    final here = await _getCurrentPlace(const NoParams());
    return here.fold((f) => f, (place) {
      emit(state.copyWith(origin: place));
      return null;
    });
  }

  Future<void> _onQueryChanged(RideQueryChanged e, Emitter<RideState> emit) async {
    emit(state.copyWith(query: e.query));
    // Attente de la fin de la frappe : un appel par pause, pas un par lettre.
    await Future<void>.delayed(_typingPause);
    if (state.query != e.query) return;
    final result = await _searchPlaces(e.query);
    if (state.query != e.query) return; // une saisie plus récente a pris le relais
    emit(state.copyWith(suggestions: result.valueOrNull ?? const []));
  }

  Future<void> _onDestinationChosen(RideDestinationChosen e, Emitter<RideState> emit) async {
    emit(state.copyWith(destination: e.place, offersStatus: LoadStatus.loading, offers: const []));
    if (state.origin.lat == null) {
      final failure = await _locate(emit);
      if (failure != null) {
        emit(state.copyWith(offersStatus: LoadStatus.failure, failure: failure));
        return;
      }
    }
    await _estimate(emit);
  }

  /// Calcule les prix du trajet choisi, avec ou sans code promo. Un code refusé est retiré et son motif signalé.
  Future<void> _estimate(Emitter<RideState> emit, {String? promoCode, bool clearPromo = false}) async {
    final to = state.destination;
    if (to == null) return;
    final code = clearPromo ? null : (promoCode ?? state.promoCode);
    emit(state.copyWith(offersStatus: LoadStatus.loading, promoCode: code, clearPromoCode: code == null));
    final result = await _estimateOffers(RouteParams(from: state.origin, to: to, promoCode: code));
    result.fold(
      (f) => emit(state.copyWith(offersStatus: LoadStatus.failure, failure: f, clearPromoCode: true)),
      (quote) {
        final offers = quote.offers;
        final stillSelected = offers.any((o) => o.category == state.selected);
        emit(
          state.copyWith(
            offersStatus: LoadStatus.ready,
            offers: offers,
            selected: stillSelected
                ? state.selected
                : offers.firstWhere((o) => o.recommended, orElse: () => offers.first).category,
            promoError: quote.promoError,
            clearPromoCode: quote.promoError != null,
          ),
        );
      },
    );
  }

  Future<void> _onBooked(RideBooked e, Emitter<RideState> emit) async {
    final to = state.destination;
    final category = state.selected;
    if (to == null || category == null) return;
    emit(state.copyWith(bookingStatus: LoadStatus.loading));
    final result = await _requestRide(
      RequestRideParams(from: state.origin, to: to, category: category, promoCode: state.promoCode),
    );
    final rideId = result.valueOrNull;
    if (rideId == null) {
      emit(state.copyWith(bookingStatus: LoadStatus.failure, failure: result.fold((f) => f, (_) => null)));
      return;
    }
    emit(state.copyWith(bookingStatus: LoadStatus.ready));
    // Le flux de la course alimente l'état jusqu'à la fin ou l'annulation.
    await emit.forEach<RideSnapshot>(
      _watchRide(rideId),
      onData: _onSnapshot,
      onError: (_, __) => state.copyWith(failure: const NetworkFailure()),
    );
  }

  Future<void> _onCancelled(RideCancelled e, Emitter<RideState> emit) async {
    final ride = state.ride;
    if (ride == null) return;
    await _cancelRide(ride.id);
  }

  Future<void> _onRated(RideRated e, Emitter<RideState> emit) async {
    final ride = state.ride;
    if (ride == null) return;
    emit(state.copyWith(ratingStatus: LoadStatus.loading));
    final result = await _rateRide(RideRating(rideId: ride.id, stars: e.stars, tags: e.tags, tip: e.tip));
    emit(
      result.fold(
        (f) => state.copyWith(ratingStatus: LoadStatus.failure, failure: f),
        (_) => state.copyWith(ratingStatus: LoadStatus.ready),
      ),
    );
  }

  /// Met l'état à jour avec la course. Une destination demandée est considérée acceptée dès que l'adresse
  /// d'arrivée de la course devient la sienne (le back n'expose pas la demande en attente).
  RideState _onSnapshot(RideSnapshot snap) {
    final pending = state.pendingDestination;
    final accepted = pending != null && snap.dropoffAddress != null && _sameAddress(snap.dropoffAddress!, pending);
    return state.copyWith(
      ride: snap,
      policy: snap.policy,
      destination: accepted ? pending : null,
      clearPendingDestination: accepted,
      notice: accepted ? 'Le chauffeur a accepté la nouvelle destination.' : null,
    );
  }

  static bool _sameAddress(String address, Place place) =>
      address.trim().toLowerCase() == (place.address.isEmpty ? place.name : place.address).trim().toLowerCase();

  Future<void> _onDestinationChange(RideDestinationChangeRequested e, Emitter<RideState> emit) async {
    final ride = state.ride;
    if (ride == null) return;
    final result = await _changeDestination(DestinationChangeParams(rideId: ride.id, newDropoff: e.place));
    emit(
      result.fold(
        (f) => state.copyWith(failure: f),
        (_) => state.copyWith(
          pendingDestination: e.place,
          notice: 'Demande envoyée au chauffeur : il doit l’accepter.',
        ),
      ),
    );
  }

  Future<void> _onPaymentSplit(RidePaymentSplitSet e, Emitter<RideState> emit) async {
    final ride = state.ride;
    if (ride == null) return;
    emit(state.copyWith(splitStatus: LoadStatus.loading));
    final result = await _setPaymentSplit(PaymentSplitParams(rideId: ride.id, walletAmount: e.walletAmount));
    emit(
      result.fold(
        (f) => state.copyWith(splitStatus: LoadStatus.failure, failure: f),
        (split) => state.copyWith(
          splitStatus: LoadStatus.ready,
          paymentSplit: split,
          notice: 'Répartition du paiement enregistrée.',
        ),
      ),
    );
  }

  Future<void> _onPromoHistory(RidePromoHistoryRequested e, Emitter<RideState> emit) async {
    final result = await _getPromoHistory(const NoParams());
    // L'historique est un plus : s'il échoue, la saisie d'un code reste possible.
    emit(state.copyWith(promoHistory: result.valueOrNull));
  }
}

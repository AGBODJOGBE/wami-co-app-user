import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/load_status.dart';
import '../../domain/entities/place.dart';
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
    required GetWaitingPolicy getWaitingPolicy,
    required RequestRide requestRide,
    required WatchRide watchRide,
    required CancelRide cancelRide,
    required RateRide rateRide,
  })  : _searchPlaces = searchPlaces,
        _estimateOffers = estimateOffers,
        _getWaitingPolicy = getWaitingPolicy,
        _requestRide = requestRide,
        _watchRide = watchRide,
        _cancelRide = cancelRide,
        _rateRide = rateRide,
        super(const RideState()) {
    on<RideStarted>(_onStarted);
    on<RideQueryChanged>(_onQueryChanged);
    on<RideDestinationChosen>(_onDestinationChosen);
    on<RideCategorySelected>((e, emit) => emit(state.copyWith(selected: e.category)));
    on<RideBooked>(_onBooked);
    on<RideCancelled>(_onCancelled);
    on<RideRated>(_onRated);
  }

  final SearchPlaces _searchPlaces;
  final EstimateRideOffers _estimateOffers;
  final GetWaitingPolicy _getWaitingPolicy;
  final RequestRide _requestRide;
  final WatchRide _watchRide;
  final CancelRide _cancelRide;
  final RateRide _rateRide;

  /// Position actuelle (géolocalisation à brancher — geolocator, à valider).
  static const currentPosition = Place(id: 'me', name: 'Ma position', address: 'Position actuelle');

  Future<void> _onStarted(RideStarted e, Emitter<RideState> emit) async {
    final policy = await _getWaitingPolicy(const NoParams());
    emit(state.copyWith(policy: policy.valueOrNull ?? const WaitingPolicy()));
    if (e.initialQuery != null) add(RideQueryChanged(e.initialQuery!));
  }

  Future<void> _onQueryChanged(RideQueryChanged e, Emitter<RideState> emit) async {
    emit(state.copyWith(query: e.query));
    final result = await _searchPlaces(e.query);
    if (state.query != e.query) return; // une saisie plus récente a pris le relais
    emit(state.copyWith(suggestions: result.valueOrNull ?? const []));
  }

  Future<void> _onDestinationChosen(RideDestinationChosen e, Emitter<RideState> emit) async {
    emit(state.copyWith(destination: e.place, offersStatus: LoadStatus.loading, offers: const []));
    final result = await _estimateOffers(RouteParams(from: state.origin, to: e.place));
    result.fold(
      (f) => emit(state.copyWith(offersStatus: LoadStatus.failure, failure: f)),
      (offers) => emit(
        state.copyWith(
          offersStatus: LoadStatus.ready,
          offers: offers,
          selected: offers.firstWhere((o) => o.recommended, orElse: () => offers.first).category,
        ),
      ),
    );
  }

  Future<void> _onBooked(RideBooked e, Emitter<RideState> emit) async {
    final to = state.destination;
    final category = state.selected;
    if (to == null || category == null) return;
    emit(state.copyWith(bookingStatus: LoadStatus.loading));
    final result = await _requestRide(RequestRideParams(from: state.origin, to: to, category: category));
    final rideId = result.valueOrNull;
    if (rideId == null) {
      emit(state.copyWith(bookingStatus: LoadStatus.failure, failure: result.fold((f) => f, (_) => null)));
      return;
    }
    emit(state.copyWith(bookingStatus: LoadStatus.ready));
    // Le flux de la course alimente l'état jusqu'à la fin ou l'annulation.
    await emit.forEach<RideSnapshot>(
      _watchRide(rideId),
      onData: (snap) => state.copyWith(ride: snap),
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
}

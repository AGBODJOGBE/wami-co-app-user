import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/load_status.dart';
import '../../domain/entities/bus.dart';
import '../../domain/services/trip_ranking.dart';
import '../../domain/usecases/bus_usecases.dart';

class BusBookingState extends Equatable {
  BusBookingState({
    BusSearchQuery? query,
    this.tripsStatus = LoadStatus.idle,
    this.trips = const [],
    this.sort = TripSort.recommended,
    this.compareIds = const {},
    this.selectedTrip,
    this.seatStatus = LoadStatus.idle,
    this.seatMap,
    this.seats = const [],
    this.bookingStatus = LoadStatus.idle,
    this.ticket,
    this.failure,
  }) : query = query ?? BusSearchQuery(from: 'Cotonou', to: 'Parakou', date: _tomorrow());

  static DateTime _tomorrow() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + 1);
  }

  static const maxCompared = 3;

  final BusSearchQuery query;
  final LoadStatus tripsStatus;
  final List<BusTrip> trips;
  final TripSort sort;
  final Set<String> compareIds;
  final BusTrip? selectedTrip;
  final LoadStatus seatStatus;
  final SeatMap? seatMap;
  final List<String> seats;
  final LoadStatus bookingStatus;
  final BusTicket? ticket;
  final Failure? failure;

  List<BusTrip> get sortedTrips => TripRanking.sort(trips, sort);
  BusTrip? get bestTrip => TripRanking.best(trips);
  List<BusTrip> get compared => trips.where((t) => compareIds.contains(t.id)).toList();
  bool get canCompare => compareIds.length >= 2;
  bool get seatsComplete => seats.length == query.passengers;

  BusBookingState copyWith({
    BusSearchQuery? query,
    LoadStatus? tripsStatus,
    List<BusTrip>? trips,
    TripSort? sort,
    Set<String>? compareIds,
    BusTrip? selectedTrip,
    LoadStatus? seatStatus,
    SeatMap? seatMap,
    List<String>? seats,
    LoadStatus? bookingStatus,
    BusTicket? ticket,
    Failure? failure,
  }) {
    return BusBookingState(
      query: query ?? this.query,
      tripsStatus: tripsStatus ?? this.tripsStatus,
      trips: trips ?? this.trips,
      sort: sort ?? this.sort,
      compareIds: compareIds ?? this.compareIds,
      selectedTrip: selectedTrip ?? this.selectedTrip,
      seatStatus: seatStatus ?? this.seatStatus,
      seatMap: seatMap ?? this.seatMap,
      seats: seats ?? this.seats,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      ticket: ticket ?? this.ticket,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [
        query,
        tripsStatus,
        trips,
        sort,
        compareIds,
        selectedTrip,
        seatStatus,
        seatMap,
        seats,
        bookingStatus,
        ticket,
        failure,
      ];
}

/// Parcours Bus : recherche → résultats → comparatif → sièges → billet.
class BusBookingCubit extends Cubit<BusBookingState> {
  BusBookingCubit({
    required SearchBusTrips searchTrips,
    required GetSeatMap getSeatMap,
    required BookBusSeats bookSeats,
  })  : _searchTrips = searchTrips,
        _getSeatMap = getSeatMap,
        _bookSeats = bookSeats,
        super(BusBookingState());

  final SearchBusTrips _searchTrips;
  final GetSeatMap _getSeatMap;
  final BookBusSeats _bookSeats;

  void swapCities() => emit(state.copyWith(query: state.query.swapped()));
  void setDate(DateTime d) => emit(state.copyWith(query: state.query.copyWith(date: d)));

  /// Changer le nombre de voyageurs réinitialise les sièges choisis.
  void setPassengers(int n) => emit(state.copyWith(query: state.query.copyWith(passengers: n), seats: const []));

  void setSort(TripSort s) => emit(state.copyWith(sort: s));

  Future<void> search() async {
    emit(state.copyWith(tripsStatus: LoadStatus.loading, compareIds: const {}));
    final result = await _searchTrips(state.query);
    result.fold(
      (f) => emit(state.copyWith(tripsStatus: LoadStatus.failure, failure: f)),
      (trips) => emit(state.copyWith(tripsStatus: LoadStatus.ready, trips: trips)),
    );
  }

  void toggleCompare(String tripId) {
    final ids = {...state.compareIds};
    if (!ids.remove(tripId)) {
      if (ids.length >= BusBookingState.maxCompared) {
        emit(state.copyWith(failure: const ValidationFailure('Vous comparez déjà 3 départs.')));
        return;
      }
      ids.add(tripId);
    }
    emit(state.copyWith(compareIds: ids));
  }

  Future<void> selectTrip(BusTrip trip) async {
    emit(state.copyWith(selectedTrip: trip, seats: const [], seatStatus: LoadStatus.loading));
    final result = await _getSeatMap(trip.id);
    result.fold(
      (f) => emit(state.copyWith(seatStatus: LoadStatus.failure, failure: f)),
      (map) => emit(state.copyWith(seatStatus: LoadStatus.ready, seatMap: map)),
    );
  }

  /// Sélection d'un siège ; au-delà du nombre de voyageurs, le plus ancien est remplacé.
  void toggleSeat(Seat seat) {
    if (seat.taken) return;
    final seats = [...state.seats];
    if (!seats.remove(seat.code)) {
      seats.add(seat.code);
      if (seats.length > state.query.passengers) seats.removeAt(0);
    }
    emit(state.copyWith(seats: seats));
  }

  Future<void> book() async {
    final trip = state.selectedTrip;
    if (trip == null) return;
    emit(state.copyWith(bookingStatus: LoadStatus.loading));
    final result = await _bookSeats(BookSeatsParams(trip: trip, query: state.query, seats: state.seats));
    result.fold(
      (f) => emit(state.copyWith(bookingStatus: LoadStatus.failure, failure: f)),
      (ticket) => emit(state.copyWith(bookingStatus: LoadStatus.ready, ticket: ticket)),
    );
  }
}

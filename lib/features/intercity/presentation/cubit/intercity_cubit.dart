import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/load_status.dart';
import '../../domain/entities/intercity.dart';
import '../../domain/usecases/intercity_usecases.dart';

class IntercityState extends Equatable {
  IntercityState({
    IntercityQuery? query,
    this.searchStatus = LoadStatus.idle,
    this.offers = const [],
    this.selected,
    this.seats = 1,
    this.payment = IntercityPayment.wallet,
    this.bookingStatus = LoadStatus.idle,
    this.booking,
    this.cancelStatus = LoadStatus.idle,
    this.failure,
  }) : query = query ?? IntercityQuery(from: 'Cotonou', to: 'Parakou', date: _tomorrow());

  static DateTime _tomorrow() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + 1);
  }

  final IntercityQuery query;
  final LoadStatus searchStatus;
  final List<IntercityOffer> offers;
  final IntercityOffer? selected;

  /// Places à réserver sur l'offre choisie (au départ, celles de la recherche).
  final int seats;
  final IntercityPayment payment;
  final LoadStatus bookingStatus;
  final IntercityBooking? booking;
  final LoadStatus cancelStatus;
  final Failure? failure;

  int get total => (selected?.pricePerSeat ?? 0) * seats;

  IntercityState copyWith({
    IntercityQuery? query,
    LoadStatus? searchStatus,
    List<IntercityOffer>? offers,
    IntercityOffer? selected,
    int? seats,
    IntercityPayment? payment,
    LoadStatus? bookingStatus,
    IntercityBooking? booking,
    LoadStatus? cancelStatus,
    Failure? failure,
  }) {
    return IntercityState(
      query: query ?? this.query,
      searchStatus: searchStatus ?? this.searchStatus,
      offers: offers ?? this.offers,
      selected: selected ?? this.selected,
      seats: seats ?? this.seats,
      payment: payment ?? this.payment,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      booking: booking ?? this.booking,
      cancelStatus: cancelStatus ?? this.cancelStatus,
      // Un échec n'est conservé que pour l'émission qui le signale.
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [
        query,
        searchStatus,
        offers,
        selected,
        seats,
        payment,
        bookingStatus,
        booking,
        cancelStatus,
        failure,
      ];
}

/// Parcours Interurbain : recherche → trajets → réservation → confirmation (et annulation).
class IntercityCubit extends Cubit<IntercityState> {
  IntercityCubit({
    required SearchIntercityOffers search,
    required BookIntercityOffer book,
    required CancelIntercityBooking cancel,
  })  : _search = search,
        _book = book,
        _cancel = cancel,
        super(IntercityState());

  final SearchIntercityOffers _search;
  final BookIntercityOffer _book;
  final CancelIntercityBooking _cancel;

  void setFrom(String city) => emit(state.copyWith(query: state.query.copyWith(from: city)));
  void setTo(String city) => emit(state.copyWith(query: state.query.copyWith(to: city)));
  void swapCities() => emit(state.copyWith(query: state.query.swapped()));
  void setDate(DateTime d) => emit(state.copyWith(query: state.query.copyWith(date: d)));
  void setSeats(int n) => emit(state.copyWith(query: state.query.copyWith(seats: n)));
  void setPayment(IntercityPayment p) => emit(state.copyWith(payment: p));

  /// Places sur l'offre choisie : jamais plus que ce qu'il reste.
  void setBookedSeats(int n) {
    final max = state.selected?.availableSeats ?? 1;
    emit(state.copyWith(seats: n.clamp(1, max < 1 ? 1 : max)));
  }

  Future<void> search() async {
    emit(state.copyWith(searchStatus: LoadStatus.loading));
    final result = await _search(state.query);
    result.fold(
      (f) => emit(state.copyWith(searchStatus: LoadStatus.failure, failure: f)),
      (offers) => emit(state.copyWith(searchStatus: LoadStatus.ready, offers: offers)),
    );
  }

  void select(IntercityOffer offer) {
    final seats = state.query.seats.clamp(1, offer.availableSeats < 1 ? 1 : offer.availableSeats);
    emit(state.copyWith(selected: offer, seats: seats, bookingStatus: LoadStatus.idle));
  }

  Future<void> book() async {
    final offer = state.selected;
    if (offer == null) return;
    emit(state.copyWith(bookingStatus: LoadStatus.loading));
    final result = await _book(BookIntercityParams(offer: offer, seats: state.seats, payment: state.payment));
    result.fold(
      (f) => emit(state.copyWith(bookingStatus: LoadStatus.failure, failure: f)),
      (booking) =>
          emit(state.copyWith(bookingStatus: LoadStatus.ready, booking: booking, cancelStatus: LoadStatus.idle)),
    );
  }

  Future<void> cancel() async {
    final booking = state.booking;
    if (booking == null || booking.status != IntercityBookingStatus.confirmed) return;
    emit(state.copyWith(cancelStatus: LoadStatus.loading));
    final result = await _cancel(booking.id);
    result.fold(
      (f) => emit(state.copyWith(cancelStatus: LoadStatus.failure, failure: f)),
      (refund) => emit(state.copyWith(cancelStatus: LoadStatus.ready, booking: booking.cancelled(refund))),
    );
  }
}

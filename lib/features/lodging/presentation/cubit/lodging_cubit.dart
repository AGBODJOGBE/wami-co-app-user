import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/load_status.dart';
import '../../domain/entities/lodging.dart';
import '../../domain/usecases/lodging_usecases.dart';

class LodgingState extends Equatable {
  const LodgingState({
    this.search = const StaySearch(),
    this.resultsStatus = LoadStatus.idle,
    this.results = const [],
    this.favorites = const {},
    this.selected,
    this.rooms = const [],
    this.roomId,
    this.payment = PaymentMethod.wallet,
    this.bookingStatus = LoadStatus.idle,
    this.booking,
    this.slots = const [],
    this.slotId,
    this.visitStatus = LoadStatus.idle,
    this.failure,
  });

  final StaySearch search;
  final LoadStatus resultsStatus;
  final List<Lodging> results;
  final Set<String> favorites;
  final Lodging? selected;
  final List<RoomOption> rooms;
  final String? roomId;
  final PaymentMethod payment;
  final LoadStatus bookingStatus;
  final Booking? booking;
  final List<VisitSlot> slots;
  final String? slotId;
  final LoadStatus visitStatus;
  final Failure? failure;

  RoomOption? get room {
    for (final r in rooms) {
      if (r.id == roomId) return r;
    }
    return rooms.isEmpty ? null : rooms.first;
  }

  VisitSlot? get slot {
    for (final s in slots) {
      if (s.id == slotId) return s;
    }
    return null;
  }

  int get total => (room?.pricePerNight ?? 0) * search.nights;

  LodgingState copyWith({
    StaySearch? search,
    LoadStatus? resultsStatus,
    List<Lodging>? results,
    Set<String>? favorites,
    Lodging? selected,
    List<RoomOption>? rooms,
    String? roomId,
    PaymentMethod? payment,
    LoadStatus? bookingStatus,
    Booking? booking,
    List<VisitSlot>? slots,
    String? slotId,
    LoadStatus? visitStatus,
    Failure? failure,
  }) {
    return LodgingState(
      search: search ?? this.search,
      resultsStatus: resultsStatus ?? this.resultsStatus,
      results: results ?? this.results,
      favorites: favorites ?? this.favorites,
      selected: selected ?? this.selected,
      rooms: rooms ?? this.rooms,
      roomId: roomId ?? this.roomId,
      payment: payment ?? this.payment,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      booking: booking ?? this.booking,
      slots: slots ?? this.slots,
      slotId: slotId ?? this.slotId,
      visitStatus: visitStatus ?? this.visitStatus,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [
        search,
        resultsStatus,
        results,
        favorites,
        selected,
        rooms,
        roomId,
        payment,
        bookingStatus,
        booking,
        slots,
        slotId,
        visitStatus,
        failure,
      ];
}

/// Parcours Hébergement. Deux branches selon le type :
/// hôtel / chambre → fiche → réservation ; appartement → fiche → demande de visite.
class LodgingCubit extends Cubit<LodgingState> {
  LodgingCubit({
    required SearchLodgings search,
    required GetRooms getRooms,
    required BookStay bookStay,
    required GetVisitSlots getVisitSlots,
    required RequestVisit requestVisit,
  })  : _search = search,
        _getRooms = getRooms,
        _bookStay = bookStay,
        _getVisitSlots = getVisitSlots,
        _requestVisit = requestVisit,
        super(const LodgingState());

  final SearchLodgings _search;
  final GetRooms _getRooms;
  final BookStay _bookStay;
  final GetVisitSlots _getVisitSlots;
  final RequestVisit _requestVisit;

  void setType(LodgingType type) {
    final priorities = type.isMonthly ? {Amenity.furnished} : {Amenity.airConditioning};
    final city = type.isMonthly ? 'Cotonou' : 'Parakou';
    emit(state.copyWith(search: state.search.copyWith(type: type, priorities: priorities, city: city)));
  }

  void setGuests(int n) => emit(state.copyWith(search: state.search.copyWith(guests: n)));

  void togglePriority(Amenity a) {
    final set = {...state.search.priorities};
    if (!set.remove(a)) set.add(a);
    emit(state.copyWith(search: state.search.copyWith(priorities: set)));
  }

  Future<void> runSearch() async {
    emit(state.copyWith(resultsStatus: LoadStatus.loading));
    final result = await _search(state.search);
    result.fold(
      (f) => emit(state.copyWith(resultsStatus: LoadStatus.failure, failure: f)),
      (list) => emit(state.copyWith(resultsStatus: LoadStatus.ready, results: list)),
    );
  }

  void toggleFavorite(String id) {
    final favs = {...state.favorites};
    if (!favs.remove(id)) favs.add(id);
    emit(state.copyWith(favorites: favs));
  }

  Future<void> open(Lodging lodging) async {
    emit(state.copyWith(selected: lodging, rooms: const [], slots: const []));
    if (lodging.type.isMonthly) {
      final r = await _getVisitSlots(lodging.id);
      r.fold(
        (f) => emit(state.copyWith(failure: f)),
        (slots) => emit(
          state.copyWith(slots: slots, slotId: slots.firstWhere((s) => s.available, orElse: () => slots.first).id),
        ),
      );
    } else {
      final r = await _getRooms(lodging.id);
      r.fold(
        (f) => emit(state.copyWith(failure: f)),
        (rooms) => emit(state.copyWith(rooms: rooms, roomId: rooms.length > 1 ? rooms[1].id : rooms.first.id)),
      );
    }
  }

  void selectRoom(String id) => emit(state.copyWith(roomId: id));
  void selectPayment(PaymentMethod m) => emit(state.copyWith(payment: m));
  void selectSlot(VisitSlot s) {
    if (s.available) emit(state.copyWith(slotId: s.id));
  }

  Future<void> book() async {
    final lodging = state.selected;
    final room = state.room;
    if (lodging == null || room == null) return;
    emit(state.copyWith(bookingStatus: LoadStatus.loading));
    final r =
        await _bookStay(BookStayParams(lodging: lodging, room: room, search: state.search, payment: state.payment));
    r.fold(
      (f) => emit(state.copyWith(bookingStatus: LoadStatus.failure, failure: f)),
      (b) => emit(state.copyWith(bookingStatus: LoadStatus.ready, booking: b)),
    );
  }

  Future<void> askVisit() async {
    final lodging = state.selected;
    final slot = state.slot;
    if (lodging == null || slot == null) return;
    emit(state.copyWith(visitStatus: LoadStatus.loading));
    final r = await _requestVisit(RequestVisitParams(apartmentId: lodging.id, slot: slot));
    r.fold(
      (f) => emit(state.copyWith(visitStatus: LoadStatus.failure, failure: f)),
      (_) => emit(state.copyWith(visitStatus: LoadStatus.ready)),
    );
  }
}

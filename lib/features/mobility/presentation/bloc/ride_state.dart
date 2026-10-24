part of 'ride_bloc.dart';

class RideState extends Equatable {
  const RideState({
    this.origin = RideBloc.currentPosition,
    this.query = '',
    this.suggestions = const [],
    this.destination,
    this.offersStatus = LoadStatus.idle,
    this.offers = const [],
    this.selected,
    this.policy = const WaitingPolicy(),
    this.bookingStatus = LoadStatus.idle,
    this.ride,
    this.ratingStatus = LoadStatus.idle,
    this.failure,
  });

  final Place origin;
  final String query;
  final List<Place> suggestions;
  final Place? destination;
  final LoadStatus offersStatus;
  final List<VehicleOffer> offers;
  final VehicleCategory? selected;
  final WaitingPolicy policy;
  final LoadStatus bookingStatus;
  final RideSnapshot? ride;
  final LoadStatus ratingStatus;
  final Failure? failure;

  VehicleOffer? get selectedOffer {
    for (final o in offers) {
      if (o.category == selected) return o;
    }
    return null;
  }

  RideState copyWith({
    String? query,
    List<Place>? suggestions,
    Place? destination,
    LoadStatus? offersStatus,
    List<VehicleOffer>? offers,
    VehicleCategory? selected,
    WaitingPolicy? policy,
    LoadStatus? bookingStatus,
    RideSnapshot? ride,
    LoadStatus? ratingStatus,
    Failure? failure,
  }) {
    return RideState(
      origin: origin,
      query: query ?? this.query,
      suggestions: suggestions ?? this.suggestions,
      destination: destination ?? this.destination,
      offersStatus: offersStatus ?? this.offersStatus,
      offers: offers ?? this.offers,
      selected: selected ?? this.selected,
      policy: policy ?? this.policy,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      ride: ride ?? this.ride,
      ratingStatus: ratingStatus ?? this.ratingStatus,
      // Un échec n'est conservé que pour l'émission qui le signale.
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [
        origin,
        query,
        suggestions,
        destination,
        offersStatus,
        offers,
        selected,
        policy,
        bookingStatus,
        ride,
        ratingStatus,
        failure,
      ];
}

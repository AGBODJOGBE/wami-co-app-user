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
    this.promoCode,
    this.promoError,
    this.availablePromos = const [],
    this.pendingDestination,
    this.paymentSplit,
    this.splitStatus = LoadStatus.idle,
    this.promoHistory,
    this.notice,
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

  /// Code promo appliqué aux prix affichés (`null` sans code).
  final String? promoCode;

  /// Motif du dernier refus de code promo, montré une fois.
  final String? promoError;
  final List<AvailablePromo> availablePromos;
  final Failure? failure;

  /// Nouvelle destination demandée, en attente de la réponse du chauffeur.
  final Place? pendingDestination;

  /// Dernière répartition du paiement confirmée par le serveur.
  final PaymentSplit? paymentSplit;
  final LoadStatus splitStatus;

  /// Historique des codes promo (`null` tant qu'il n'est pas chargé).
  final PromoHistory? promoHistory;

  /// Message d'information montré une fois (demande envoyée, répartition enregistrée…).
  final String? notice;

  VehicleOffer? get selectedOffer {
    for (final o in offers) {
      if (o.category == selected) return o;
    }
    return null;
  }

  RideState copyWith({
    Place? origin,
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
    String? promoCode,
    bool clearPromoCode = false,
    String? promoError,
    List<AvailablePromo>? availablePromos,
    Place? pendingDestination,
    bool clearPendingDestination = false,
    PaymentSplit? paymentSplit,
    LoadStatus? splitStatus,
    PromoHistory? promoHistory,
    String? notice,
    Failure? failure,
  }) {
    return RideState(
      origin: origin ?? this.origin,
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
      promoCode: clearPromoCode ? null : (promoCode ?? this.promoCode),
      // Comme `failure`, le motif de refus n'est conservé que pour l'émission qui le signale.
      promoError: promoError,
      availablePromos: availablePromos ?? this.availablePromos,
      // Un échec n'est conservé que pour l'émission qui le signale.
      pendingDestination: clearPendingDestination ? null : (pendingDestination ?? this.pendingDestination),
      paymentSplit: paymentSplit ?? this.paymentSplit,
      splitStatus: splitStatus ?? this.splitStatus,
      promoHistory: promoHistory ?? this.promoHistory,
      // Comme `failure`, le message n'est conservé que pour l'émission qui le signale.
      notice: notice,
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
        promoCode,
        promoError,
        availablePromos,
        pendingDestination,
        paymentSplit,
        splitStatus,
        promoHistory,
        notice,
        failure,
      ];
}

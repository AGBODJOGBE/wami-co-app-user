import '../domain/service_type.dart';

/// Chemins de navigation de l'application.
abstract final class Routes {
  // Connexion.
  static const auth = '/auth';

  // Onglets.
  static const home = '/home';
  static const activities = '/activities';
  static const wallet = '/wallet';
  static const account = '/account';

  // Portefeuille.
  static const walletTopUp = '/wallet/top-up';
  static const walletTransfer = '/wallet/transfer';
  static const walletTransferReview = '/wallet/transfer/review';
  static const walletSuccess = '/wallet/success';

  // Compte.
  static const accountProfile = '/account/profile';
  static const accountSettings = '/account/settings';
  static const accountSupport = '/account/support';
  static const accountPrivacy = '/account/privacy';

  // Parcours Mobilité.
  static const ride = '/ride';
  static const rideOffers = '/ride/offers';
  static const rideTrack = '/ride/track';
  static const rideRate = '/ride/rate';

  // Parcours Livraison.
  static const delivery = '/delivery';
  static const deliveryParcel = '/delivery/parcel';
  static const deliveryQuote = '/delivery/quote';
  static const deliveryTrack = '/delivery/track';

  // Parcours Bus.
  static const bus = '/bus';
  static const busResults = '/bus/results';
  static const busCompare = '/bus/compare';
  static const busSeats = '/bus/seats';
  static const busTicket = '/bus/ticket';

  // Parcours Hébergement.
  static const stay = '/stay';
  static const stayResults = '/stay/results';
  static const stayDetail = '/stay/detail';
  static const stayConfirm = '/stay/confirm';
  static const stayBooked = '/stay/booked';
  static const stayApartment = '/stay/apartment';
  static const stayVisitSent = '/stay/visit-sent';

  static String forService(ServiceType s) => switch (s) {
        ServiceType.mobility => ride,
        ServiceType.delivery => delivery,
        ServiceType.bus => bus,
        ServiceType.lodging => stay,
      };
}

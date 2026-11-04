import 'package:flutter_test/flutter_test.dart';
import 'package:wami/core/config/app_config.dart';
import 'package:wami/core/data/fake_backend.dart';
import 'package:wami/core/location/location_service.dart';
import 'package:wami/features/mobility/data/datasources/mobility_fake_data_source.dart';
import 'package:wami/features/mobility/data/repositories/mobility_repository_impl.dart';
import 'package:wami/features/mobility/domain/entities/place.dart';
import 'package:wami/features/mobility/domain/entities/ride.dart';
import 'package:wami/features/mobility/domain/entities/vehicle_offer.dart';
import 'package:wami/features/mobility/domain/usecases/mobility_usecases.dart';
import 'package:wami/features/mobility/presentation/bloc/ride_bloc.dart';

/// Test d'intégration du parcours complet sur le backend simulé (pas de 1 ms).
void main() {
  late RideBloc bloc;

  setUp(() {
    const config = AppConfig(apiBaseUrl: '', useFakeBackend: true, fakeLatency: Duration.zero);
    final ds = MobilityFakeDataSource(const FakeBackend(config), tick: const Duration(milliseconds: 1));
    final repo = MobilityRepositoryImpl(ds, const FixedLocationService());
    bloc = RideBloc(
      getCurrentPlace: GetCurrentPlace(repo),
      getAvailablePromos: GetAvailablePromos(repo),
      searchPlaces: SearchPlaces(repo),
      estimateOffers: EstimateRideOffers(repo),
      getWaitingPolicy: GetWaitingPolicy(repo),
      requestRide: RequestRide(repo),
      watchRide: WatchRide(repo),
      cancelRide: CancelRide(repo),
      rateRide: RateRide(repo),
      changeDestination: ChangeRideDestination(repo),
      setPaymentSplit: SetPaymentSplit(repo),
      getPromoHistory: GetPromoHistory(repo),
    );
  });

  tearDown(() => bloc.close());

  test('les offres sont triées par prix et la moto est recommandée', () async {
    bloc.add(const RideDestinationChosen(Place(id: 'x', name: 'Dantokpa', address: 'Cotonou')));
    final s = await bloc.stream.firstWhere((s) => s.offers.isNotEmpty);
    expect(s.offers.first.category, VehicleCategory.moto);
    expect(s.selected, VehicleCategory.moto);
  });

  test('code promo : remise appliquée, refus signalé puis retrait', () async {
    bloc.add(const RideDestinationChosen(Place(id: 'x', name: 'Dantokpa', address: 'Cotonou')));
    final before = (await bloc.stream.firstWhere((s) => s.offers.isNotEmpty)).offers.first.price;

    bloc.add(const RidePromoApplied(' wami10 '));
    final applied = await bloc.stream.firstWhere((s) => s.promoCode != null && s.offersStatus.name == 'ready');
    expect(applied.promoCode, 'WAMI10');
    expect(applied.offers.first.price, lessThan(before));
    expect(applied.offers.first.discount, before - applied.offers.first.price);

    bloc.add(const RidePromoApplied('FAUX'));
    final refused = await bloc.stream.firstWhere((s) => s.promoError != null);
    expect(refused.promoError, 'Code promo inconnu.');
    // Un code refusé est retiré : les prix reviennent sans remise.
    expect(refused.promoCode, isNull);

    bloc.add(const RidePromoApplied('WAMI10'));
    await bloc.stream.firstWhere((s) => s.promoCode == 'WAMI10' && s.offersStatus.name == 'ready');
    bloc.add(const RidePromoRemoved());
    final removed = await bloc.stream.firstWhere((s) => s.promoCode == null && s.offersStatus.name == 'ready');
    expect(removed.offers.first.price, before);
  });

  test('déroulé : recherche → arrivé (attente facturée) → course → pause → terminée', () async {
    bloc.add(const RideDestinationChosen(Place(id: 'x', name: 'Dantokpa', address: 'Cotonou')));
    await bloc.stream.firstWhere((s) => s.offers.isNotEmpty);

    final seen = <RideStatus>{};
    var billedWaiting = false;
    final sub = bloc.stream.listen((s) {
      final r = s.ride;
      if (r == null) return;
      seen.add(r.status);
      if (r.status == RideStatus.driverArrived && r.waitingFee > 0) billedWaiting = true;
    });

    bloc.add(const RideBooked());
    await bloc.stream.firstWhere((s) => s.ride?.status == RideStatus.completed).timeout(const Duration(seconds: 10));
    await sub.cancel();

    expect(
      seen,
      containsAll([
        RideStatus.searching,
        RideStatus.driverEnRoute,
        RideStatus.driverArrived,
        RideStatus.inProgress,
        RideStatus.paused,
      ]),
    );
    expect(billedWaiting, isTrue);
    expect(bloc.state.ride!.total, greaterThan(bloc.state.ride!.fare));
  });

  test('historique des codes promo chargé à la demande', () async {
    bloc.add(const RidePromoHistoryRequested());
    final s = await bloc.stream.firstWhere((s) => s.promoHistory != null);
    expect(s.promoHistory!.usages, isNotEmpty);
    expect(s.promoHistory!.totalDiscount, greaterThan(0));
  });

  test('en course : destination demandée puis répartition du paiement enregistrée', () async {
    bloc.add(const RideDestinationChosen(Place(id: 'x', name: 'Dantokpa', address: 'Cotonou')));
    await bloc.stream.firstWhere((s) => s.offers.isNotEmpty);
    bloc.add(const RideBooked());
    await bloc.stream.firstWhere((s) => s.ride != null);

    const godomey = Place(id: 'g', name: 'Godomey', address: 'Godomey', lat: 6.38, lng: 2.34);
    bloc.add(const RideDestinationChangeRequested(godomey));
    final asked = await bloc.stream.firstWhere((s) => s.pendingDestination != null);
    expect(asked.pendingDestination, godomey);

    bloc.add(const RidePaymentSplitSet(800));
    final saved = await bloc.stream.firstWhere((s) => s.paymentSplit != null);
    expect(saved.paymentSplit!.walletAmount, 800);
  });

  test('destination sans coordonnées et montant négatif sont refusés avant tout appel', () async {
    const sans = Place(id: 'm', name: 'Point', address: '[Adresse]');
    const config = AppConfig(apiBaseUrl: '', useFakeBackend: true, fakeLatency: Duration.zero);
    final repo =
        MobilityRepositoryImpl(MobilityFakeDataSource(const FakeBackend(config)), const FixedLocationService());

    final destination = await ChangeRideDestination(repo)(const DestinationChangeParams(rideId: 'r', newDropoff: sans));
    final split = await SetPaymentSplit(repo)(const PaymentSplitParams(rideId: 'r', walletAmount: -1));
    expect(destination.isOk, isFalse);
    expect(split.isOk, isFalse);
  });
}

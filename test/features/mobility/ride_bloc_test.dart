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
      searchPlaces: SearchPlaces(repo),
      estimateOffers: EstimateRideOffers(repo),
      getWaitingPolicy: GetWaitingPolicy(repo),
      requestRide: RequestRide(repo),
      watchRide: WatchRide(repo),
      cancelRide: CancelRide(repo),
      rateRide: RateRide(repo),
    );
  });

  tearDown(() => bloc.close());

  test('les offres sont triées par prix et la moto est recommandée', () async {
    bloc.add(const RideDestinationChosen(Place(id: 'x', name: 'Dantokpa', address: 'Cotonou')));
    final s = await bloc.stream.firstWhere((s) => s.offers.isNotEmpty);
    expect(s.offers.first.category, VehicleCategory.moto);
    expect(s.selected, VehicleCategory.moto);
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
}

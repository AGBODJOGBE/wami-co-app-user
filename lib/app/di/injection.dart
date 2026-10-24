import '../../core/config/app_config.dart';
import '../../core/data/fake_backend.dart';
import '../../core/di/service_locator.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_interceptor.dart';
import '../../features/account/data/datasources/account_data_sources.dart';
import '../../features/account/data/repositories/account_repository_impl.dart';
import '../../features/account/domain/repositories/account_repository.dart';
import '../../features/account/domain/usecases/account_usecases.dart';
import '../../features/account/presentation/cubit/profile_cubit.dart';
import '../../features/account/presentation/cubit/settings_cubit.dart';
import '../../features/account/presentation/cubit/support_cubit.dart';
import '../../features/activities/data/activity_repository_impl.dart';
import '../../features/activities/domain/activity.dart';
import '../../features/activities/presentation/activities_page.dart';
import '../../features/bus/data/datasources/bus_data_sources.dart';
import '../../features/bus/data/repositories/bus_repository_impl.dart';
import '../../features/bus/domain/repositories/bus_repository.dart';
import '../../features/bus/domain/usecases/bus_usecases.dart';
import '../../features/bus/presentation/cubit/bus_booking_cubit.dart';
import '../../features/delivery/data/datasources/delivery_data_sources.dart';
import '../../features/delivery/data/repositories/delivery_repository_impl.dart';
import '../../features/delivery/domain/repositories/delivery_repository.dart';
import '../../features/delivery/domain/usecases/delivery_usecases.dart';
import '../../features/delivery/presentation/cubit/delivery_cubit.dart';
import '../../features/home/data/datasources/home_remote_data_source.dart';
import '../../features/home/data/repositories/home_repository_impl.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/home/domain/usecases/get_home_feed.dart';
import '../../features/home/presentation/cubit/home_cubit.dart';
import '../../features/lodging/data/datasources/lodging_data_sources.dart';
import '../../features/lodging/data/repositories/lodging_repository_impl.dart';
import '../../features/lodging/domain/repositories/lodging_repository.dart';
import '../../features/lodging/domain/usecases/lodging_usecases.dart';
import '../../features/lodging/presentation/cubit/lodging_cubit.dart';
import '../../features/mobility/data/datasources/mobility_fake_data_source.dart';
import '../../features/mobility/data/datasources/mobility_remote_data_source.dart';
import '../../features/mobility/data/repositories/mobility_repository_impl.dart';
import '../../features/mobility/domain/repositories/mobility_repository.dart';
import '../../features/mobility/domain/usecases/mobility_usecases.dart';
import '../../features/mobility/presentation/bloc/ride_bloc.dart';
import '../../features/wallet/data/datasources/wallet_data_sources.dart';
import '../../features/wallet/data/repositories/wallet_repository_impl.dart';
import '../../features/wallet/domain/repositories/wallet_repository.dart';
import '../../features/wallet/domain/usecases/wallet_usecases.dart';
import '../../features/wallet/presentation/bloc/wallet_bloc.dart';
import '../router/app_router.dart';

/// Racine de composition : c'est le seul endroit qui connaît toutes les couches.
///
/// Règles :
/// - sources de données, repositories, cas d'usage : `registerLazySingleton` ;
/// - blocs et cubits : `registerFactory` (une instance neuve par écran ou parcours) ;
/// - `config.useFakeBackend` choisit la source simulée ou la source HTTP.
Future<void> configureDependencies(AppConfig config) async {
  sl
    ..registerSingleton<AppConfig>(config)
    ..registerLazySingleton(AuthInterceptor.new)
    ..registerLazySingleton(() => ApiClient(sl(), sl()))
    ..registerLazySingleton(() => FakeBackend(sl()))
    ..registerLazySingleton(AppRouter.new);

  final fake = config.useFakeBackend;

  _home(fake);
  _mobility(fake);
  _delivery(fake);
  _bus(fake);
  _lodging(fake);
  _wallet(fake);
  _account(fake);
  _activities(fake);
}

void _home(bool fake) {
  sl
    ..registerLazySingleton<HomeRemoteDataSource>(() => fake ? HomeFakeDataSource(sl()) : HomeApiDataSource(sl()))
    ..registerLazySingleton<HomeRepository>(() => HomeRepositoryImpl(sl()))
    ..registerLazySingleton(() => GetHomeFeed(sl()))
    ..registerFactory(() => HomeCubit(sl()));
}

void _mobility(bool fake) {
  sl
    ..registerLazySingleton<MobilityRemoteDataSource>(
      () => fake ? MobilityFakeDataSource(sl()) : MobilityApiDataSource(sl()),
    )
    ..registerLazySingleton<MobilityRepository>(() => MobilityRepositoryImpl(sl()))
    ..registerLazySingleton(() => SearchPlaces(sl()))
    ..registerLazySingleton(() => EstimateRideOffers(sl()))
    ..registerLazySingleton(() => GetWaitingPolicy(sl()))
    ..registerLazySingleton(() => RequestRide(sl()))
    ..registerLazySingleton(() => WatchRide(sl()))
    ..registerLazySingleton(() => CancelRide(sl()))
    ..registerLazySingleton(() => RateRide(sl()))
    ..registerFactory(
      () => RideBloc(
        searchPlaces: sl(),
        estimateOffers: sl(),
        getWaitingPolicy: sl(),
        requestRide: sl(),
        watchRide: sl(),
        cancelRide: sl(),
        rateRide: sl(),
      ),
    );
}

void _delivery(bool fake) {
  sl
    ..registerLazySingleton<DeliveryRemoteDataSource>(
      () => fake ? DeliveryFakeDataSource(sl()) : DeliveryApiDataSource(sl()),
    )
    ..registerLazySingleton<DeliveryRepository>(() => DeliveryRepositoryImpl(sl()))
    ..registerLazySingleton(() => const ValidateDeliveryAddresses())
    ..registerLazySingleton(() => GetDeliveryQuotes(sl()))
    ..registerLazySingleton(() => PlaceDeliveryOrder(sl()))
    ..registerLazySingleton(() => TrackDelivery(sl()))
    ..registerFactory(() => DeliveryCubit(validate: sl(), getQuotes: sl(), placeOrder: sl(), track: sl()));
}

void _bus(bool fake) {
  sl
    ..registerLazySingleton<BusRemoteDataSource>(() => fake ? BusFakeDataSource(sl()) : BusApiDataSource(sl()))
    ..registerLazySingleton<BusRepository>(() => BusRepositoryImpl(sl()))
    ..registerLazySingleton(() => SearchBusTrips(sl()))
    ..registerLazySingleton(() => GetSeatMap(sl()))
    ..registerLazySingleton(() => BookBusSeats(sl()))
    ..registerFactory(() => BusBookingCubit(searchTrips: sl(), getSeatMap: sl(), bookSeats: sl()));
}

void _lodging(bool fake) {
  sl
    ..registerLazySingleton<LodgingRemoteDataSource>(
      () => fake ? LodgingFakeDataSource(sl()) : LodgingApiDataSource(sl()),
    )
    ..registerLazySingleton<LodgingRepository>(() => LodgingRepositoryImpl(sl()))
    ..registerLazySingleton(() => SearchLodgings(sl()))
    ..registerLazySingleton(() => GetRooms(sl()))
    ..registerLazySingleton(() => BookStay(sl()))
    ..registerLazySingleton(() => GetVisitSlots(sl()))
    ..registerLazySingleton(() => RequestVisit(sl()))
    ..registerFactory(
      () => LodgingCubit(search: sl(), getRooms: sl(), bookStay: sl(), getVisitSlots: sl(), requestVisit: sl()),
    );
}

void _wallet(bool fake) {
  sl
    ..registerLazySingleton<WalletRemoteDataSource>(
      () => fake ? WalletFakeDataSource(sl()) : WalletApiDataSource(sl()),
    )
    ..registerLazySingleton<WalletRepository>(() => WalletRepositoryImpl(sl()))
    ..registerLazySingleton(() => GetWalletOverview(sl()))
    ..registerLazySingleton(() => GetTopUpSources(sl()))
    ..registerLazySingleton(() => GetBeneficiaries(sl()))
    ..registerLazySingleton(() => TopUpWallet(sl()))
    ..registerLazySingleton(() => TransferMoney(sl()))
    ..registerFactory(
      () => WalletBloc(getOverview: sl(), getSources: sl(), getBeneficiaries: sl(), topUp: sl(), transfer: sl()),
    );
}

void _account(bool fake) {
  sl
    ..registerLazySingleton<AccountRemoteDataSource>(
      () => fake ? AccountFakeDataSource(sl()) : AccountApiDataSource(sl()),
    )
    ..registerLazySingleton<SettingsLocalDataSource>(InMemorySettingsDataSource.new)
    ..registerLazySingleton<AccountRepository>(() => AccountRepositoryImpl(sl(), sl()))
    ..registerLazySingleton(() => GetProfile(sl()))
    ..registerLazySingleton(() => UpdateProfile(sl()))
    ..registerLazySingleton(() => GetSettings(sl()))
    ..registerLazySingleton(() => SaveSettings(sl()))
    ..registerLazySingleton(() => GetFaq(sl()))
    ..registerLazySingleton(() => RequestDataExport(sl()))
    ..registerFactory(() => ProfileCubit(sl(), sl()))
    ..registerFactory(() => SettingsCubit(sl(), sl()))
    ..registerFactory(() => SupportCubit(sl(), sl()));
}

void _activities(bool fake) {
  sl
    ..registerLazySingleton<ActivityRemoteDataSource>(
      () => fake ? ActivityFakeDataSource(sl()) : ActivityApiDataSource(sl()),
    )
    ..registerLazySingleton<ActivityRepository>(() => ActivityRepositoryImpl(sl()))
    ..registerLazySingleton(() => GetActivities(sl()))
    ..registerFactory(() => ActivitiesCubit(sl()));
}

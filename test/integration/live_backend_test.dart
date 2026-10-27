@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wami/core/auth/current_session.dart';
import 'package:wami/core/config/app_config.dart';
import 'package:wami/core/error/exceptions.dart';
import 'package:wami/core/network/api_client.dart';
import 'package:wami/core/network/auth_interceptor.dart';
import 'package:wami/features/auth/data/datasources/auth_data_sources.dart';
import 'package:wami/features/mobility/data/datasources/mobility_remote_data_source.dart';
import 'package:wami/features/mobility/data/datasources/place_geocoder.dart';
import 'package:wami/features/mobility/domain/entities/place.dart';
import 'package:wami/features/mobility/domain/entities/ride.dart';
import 'package:wami/features/mobility/domain/entities/vehicle_offer.dart';
import 'package:wami/features/wallet/data/datasources/wallet_data_sources.dart';

/// Test contre un vrai back wami-co. Ignoré sans `WAMI_LIVE_API`.
///
/// ```bash
/// WAMI_LIVE_API=http://localhost:3000 WAMI_LIVE_PHONE=+2290197123456 WAMI_LIVE_PASSWORD=Motdepasse1 \
///   flutter test test/integration --tags live
/// ```
/// Le compte doit déjà exister (inscription par code SMS, voir README).
class _NoGeocoder implements PlaceGeocoder {
  @override
  Future<List<Place>> search(String query) async => const [];
}

void main() {
  final url = Platform.environment['WAMI_LIVE_API'];
  final phone = Platform.environment['WAMI_LIVE_PHONE'];
  final password = Platform.environment['WAMI_LIVE_PASSWORD'];
  final skip = (url == null || phone == null || password == null)
      ? 'WAMI_LIVE_API, WAMI_LIVE_PHONE et WAMI_LIVE_PASSWORD requis'
      : false;

  late CurrentSession session;
  late ApiClient api;

  const from = Place(id: 'me', name: 'Ma position', address: 'Position actuelle', lat: 6.3654, lng: 2.4183);
  const to = Place(id: 'x', name: 'Dantokpa', address: 'Cotonou', lat: 6.3703, lng: 2.4300);

  setUpAll(() async {
    if (skip != false) return;
    session = CurrentSession();
    api = ApiClient(AppConfig(apiBaseUrl: url!, useFakeBackend: false), AuthInterceptor(session));
    session.set(await AuthApiDataSource(api).login(phone!, password!));
  });

  test(
    'connexion : la session porte le portefeuille',
    () {
      expect(session.value!.walletId, isNotEmpty);
      expect(session.value!.phone, phone);
    },
    skip: skip,
  );

  test(
    'mauvais mot de passe : refusé',
    () async {
      final anonymous =
          ApiClient(AppConfig(apiBaseUrl: url!, useFakeBackend: false), AuthInterceptor(CurrentSession()));
      expect(() => AuthApiDataSource(anonymous).login(phone!, 'Mauvais1pass'), throwsA(isA<Exception>()));
    },
    skip: skip,
  );

  test(
    'portefeuille : solde et historique',
    () async {
      final overview = await WalletApiDataSource(api, session).overview();
      expect(overview.wallet.balance, greaterThanOrEqualTo(0));
      expect(overview.wallet.holder, session.value!.fullName);
    },
    skip: skip,
  );

  test(
    'transfert vers soi-même : refusé en français',
    () async {
      expect(
        () => WalletApiDataSource(api, session).transfer(phone!, 100, null),
        throwsA(isA<BusinessRuleException>()),
      );
    },
    skip: skip,
  );

  test(
    'recharge : le back est compris (réussie, refusée ou en attente, jamais une erreur de format)',
    () async {
      final wallet = WalletApiDataSource(
        api,
        session,
        pollEvery: const Duration(milliseconds: 200),
        pollFor: const Duration(seconds: 1),
      );
      try {
        await wallet.topUp(500, phone!);
      } on BusinessRuleException catch (e) {
        // Sans clés d'opérateur (local), le back répond 502 : l'app doit le traduire.
        expect(e.code, anyOf('payment_failed', 'payment_pending'));
      }
    },
    skip: skip,
  );

  test(
    'course : estimation, demande, suivi, annulation',
    () async {
      final rides = MobilityApiDataSource(api, session, _NoGeocoder(), pollEvery: const Duration(milliseconds: 300));

      final offers = await rides.estimate(from, to);
      expect(offers.length, VehicleCategory.values.length);
      expect(offers.where((o) => o.recommended), hasLength(1));
      expect(offers.every((o) => o.price > 0), isTrue);

      final id = await rides.requestRide(from, to, VehicleCategory.moto);
      final first = await rides.watchRide(id).first;
      expect(first.id, id);
      expect(first.status, RideStatus.searching);
      expect(first.category, VehicleCategory.moto);
      expect(first.fare, offers.firstWhere((o) => o.category == VehicleCategory.moto).price);
      expect(first.policy, isNotNull);

      await rides.cancelRide(id);
      final last = await rides.watchRide(id).last;
      expect(last.status, RideStatus.cancelled);
    },
    skip: skip,
  );
}

@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wami/core/auth/auth_session.dart';
import 'package:wami/core/app_info/app_info.dart';
import 'package:wami/core/auth/current_session.dart';
import 'package:wami/core/config/app_config.dart';
import 'package:wami/core/error/exceptions.dart';
import 'package:wami/core/location/location_service.dart';
import 'package:wami/core/location/place_geocoder.dart';
import 'package:wami/core/network/api_client.dart';
import 'package:wami/core/network/auth_interceptor.dart';
import 'package:wami/core/network/realtime_signals.dart';
import 'package:wami/features/account/data/datasources/account_data_sources.dart';
import 'package:wami/features/account/domain/entities/user_profile.dart';
import 'package:wami/features/activities/data/activity_repository_impl.dart';
import 'package:wami/features/app_update/data/datasources/app_update_data_sources.dart';
import 'package:wami/features/auth/data/datasources/auth_data_sources.dart';
import 'package:wami/features/delivery/data/datasources/delivery_data_sources.dart';
import 'package:wami/features/delivery/domain/entities/delivery.dart';
import 'package:wami/features/intercity/data/datasources/intercity_data_sources.dart';
import 'package:wami/features/intercity/domain/entities/intercity.dart';
import 'package:wami/features/mobility/data/datasources/mobility_remote_data_source.dart';
import 'package:wami/features/notifications/data/datasources/notifications_data_sources.dart';
import 'package:wami/features/referral/data/datasources/referral_data_sources.dart';
import 'package:wami/features/mobility/domain/entities/place.dart';
import 'package:wami/features/mobility/domain/entities/ride.dart';
import 'package:wami/features/mobility/domain/entities/vehicle_offer.dart';
import 'package:wami/features/wallet/data/datasources/wallet_data_sources.dart';
import 'package:wami/features/wallet/domain/entities/wallet.dart';

/// Test contre un vrai back wami-co. Ignoré sans `WAMI_LIVE_API`.
///
/// ```bash
/// WAMI_LIVE_API=http://localhost:3000 WAMI_LIVE_PHONE=+2290197123456 WAMI_LIVE_PASSWORD=Motdepasse1 \
///   flutter test test/integration --tags live
/// ```
/// Le compte doit déjà exister (inscription par code SMS, voir README).
/// Le back limite les connexions (5 par 15 minutes) : ne pas enchaîner les exécutions.
class _FixedGeocoder implements PlaceGeocoder {
  @override
  Future<List<GeocodedPlace>> search(String query) async => const [
        GeocodedPlace(id: '1', name: 'Fidjrossè', address: 'Cotonou', lat: 6.3703, lng: 2.4300),
      ];
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
    'profil : identité lue sur le back',
    () async {
      final p = await AccountApiDataSource(api, session).profile();
      expect(p.fullName, session.value!.fullName);
      expect(p.phone, phone);
    },
    skip: skip,
  );

  test(
    'activités : courses et livraisons lues sur le back',
    () async {
      final list = await ActivityApiDataSource(api).fetch();
      expect(list, isNotEmpty);
      expect(list.every((a) => a.title.isNotEmpty && a.id.isNotEmpty), isTrue);
      expect(list.where((a) => a.service.name == 'mobility'), isNotEmpty);
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
    'transfert vers soi-même : refusé',
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
    'livraison : devis, commande, suivi, annulation, activités',
    () async {
      final deliveries = DeliveryApiDataSource(
        api,
        session,
        const FixedLocationService(GeoPoint(6.3654, 2.4183)),
        _FixedGeocoder(),
        pollEvery: const Duration(milliseconds: 300),
      );
      const draft = DeliveryDraft(
        dropoffAddress: 'Fidjrossè plage',
        contactName: 'Koffi',
        contactPhone: '01 97 00 00 01',
        size: ParcelSize.small,
      );

      final quotes = await deliveries.quotes(draft);
      expect(quotes, isNotEmpty);
      expect(quotes.every((q) => q.price > 0), isTrue);
      expect(quotes.map((q) => q.vehicle), contains(DeliveryVehicle.moto));

      final id = await deliveries.placeOrder(draft.copyWith(vehicle: DeliveryVehicle.moto));
      expect(id, isNotEmpty);
      try {
        // Aucun coursier en local : le suivi reste en attente (aucune étape), sans erreur de format.
        await deliveries.track(id).timeout(const Duration(seconds: 2), onTimeout: (sink) => sink.close()).toList();
      } finally {
        await api.delete('/api/passenger/delivery/$id');
      }
      final list = await ActivityApiDataSource(api).fetch();
      expect(list.where((a) => a.service.name == 'delivery').first.status.name, 'cancelled');
    },
    skip: skip,
  );

  test(
    'mot de passe : le mauvais mot de passe actuel est refusé sans fermer la session, puis changement et retour',
    () async {
      final account = AccountApiDataSource(api, session);
      await expectLater(
        account.changePassword('Mauvais1pass', 'Temporaire9pass'),
        throwsA(isA<BusinessRuleException>().having((e) => e.message, 'message', 'Mot de passe actuel incorrect.')),
      );
      // La session est toujours valable : le profil se lit.
      expect((await account.profile()).phone, phone);

      await account.changePassword(password!, 'Temporaire9pass');
      // Remet le mot de passe d'origine pour ne pas gêner les exécutions suivantes.
      await account.changePassword('Temporaire9pass', password);
    },
    skip: skip,
  );

  test(
    'code promo : un code inconnu est refusé en français, un code proposé est appliqué ou refusé avec un motif',
    () async {
      final rides = MobilityApiDataSource(api, session, _FixedGeocoder(), pollEvery: const Duration(milliseconds: 300));

      final unknown = await rides.estimate(from, to, promoCode: 'CODEINCONNU');
      expect(unknown.promoError, 'Code promo inconnu.');
      expect(unknown.offers.every((o) => o.discount == 0), isTrue);

      final promos = await rides.availablePromos();
      expect(promos.every((p) => p.code.isNotEmpty), isTrue);
      if (promos.isNotEmpty) {
        final quote = await rides.estimate(from, to, promoCode: promos.first.code);
        // Soit une remise réelle, soit un refus expliqué (ex. réservé aux nouveaux clients).
        expect(quote.offers.any((o) => o.discount > 0) || (quote.promoError ?? '').isNotEmpty, isTrue);
        for (final o in quote.offers.where((o) => o.discount > 0)) {
          expect(o.price, lessThan(o.fullPrice));
        }
      }
    },
    skip: skip,
  );

  test(
    'parrainage : code et filleuls lus, code inconnu et propre code refusés',
    () async {
      final referral = ReferralApiDataSource(api);
      final overview = await referral.overview();
      expect(overview.code, isNotEmpty);
      expect(overview.total, greaterThanOrEqualTo(overview.pendingCount + overview.validatedCount));

      await expectLater(
        referral.apply('ZZZ999'),
        throwsA(isA<BusinessRuleException>().having((e) => e.message, 'message', 'Code de parrainage inconnu.')),
      );
      await expectLater(
        referral.apply(overview.code),
        throwsA(isA<BusinessRuleException>().having((e) => e.message, 'message', contains('propre code'))),
      );
    },
    skip: skip,
  );

  test(
    'notifications : page lue sans erreur de format, marquage comme lue, notification inconnue tolérée',
    () async {
      final notifications = NotificationsApiDataSource(api);
      final page = await notifications.page(1);
      expect(page.page, 1);
      expect(page.totalPages, greaterThanOrEqualTo(1));
      expect(page.items.every((n) => n.id.isNotEmpty && n.type.isNotEmpty), isTrue);
      if (page.items.isNotEmpty) await notifications.markAsRead(page.items.first.id);
      await notifications.markAsRead('notification-inconnue');
    },
    skip: skip,
  );

  test(
    'version de l’application : une version récente est à jour, une très ancienne a une mise à jour',
    () async {
      AppUpdateApiDataSource source(String version) =>
          AppUpdateApiDataSource(api, FixedAppInfoSource(AppInfo(version: version, platform: 'ANDROID')));

      final recent = await source('999.0.0').check();
      expect(recent.updateAvailable, isFalse);
      expect(recent.forceUpdate, isFalse);

      final old = await source('0.0.1').check();
      expect(old.updateAvailable, isTrue);
      expect(old.latestVersion, isNotEmpty);
    },
    skip: skip,
  );

  test(
    'course : estimation, demande, suivi, annulation',
    () async {
      final rides = MobilityApiDataSource(api, session, _FixedGeocoder(), pollEvery: const Duration(milliseconds: 300));

      final offers = (await rides.estimate(from, to)).offers;
      expect(offers.length, VehicleCategory.values.length);
      expect(offers.where((o) => o.recommended), hasLength(1));
      expect(offers.every((o) => o.price > 0), isTrue);
      // Chauffeurs proches : inconnu, ou un nombre ; avec des chauffeurs, un délai d'arrivée est donné.
      for (final o in offers) {
        expect(o.nearbyDrivers == null || o.nearbyDrivers! >= 0, isTrue);
        if ((o.nearbyDrivers ?? 0) > 0) expect(o.arrivalMinutes, isNotNull);
        if (o.noDriverNearby) expect(o.arrivalMinutes, isNull);
      }

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

  test(
    'course : répartition du paiement enregistrée, changement de destination refusé hors course, historique promo',
    () async {
      final rides = MobilityApiDataSource(api, session, _FixedGeocoder(), pollEvery: const Duration(milliseconds: 300));

      final history = await rides.promoHistory();
      expect(history.totalDiscount, greaterThanOrEqualTo(0));
      expect(history.usages.every((u) => u.code.isNotEmpty), isTrue);

      final id = await rides.requestRide(from, to, VehicleCategory.moto);
      try {
        final split = await rides.setPaymentSplit(id, 500);
        expect(split.walletAmount, 500);
        expect((await rides.setPaymentSplit(id, null)).isAutomatic, isTrue);

        // La course n'a pas démarré : le back refuse le changement de destination, en le disant.
        await expectLater(
          rides.requestDestinationChange(id, to),
          throwsA(isA<BusinessRuleException>().having((e) => e.message, 'message', isNotEmpty)),
        );
      } finally {
        await rides.cancelRide(id);
      }
    },
    skip: skip,
  );

  test(
    'interurbain : recherche lue, réservation, double réservation refusée en français, annulation remboursée',
    () async {
      final intercity = IntercityApiDataSource(api);
      final day = DateTime.now().add(const Duration(days: 2));
      final offers = await intercity.search(IntercityQuery(from: 'Cotonou', to: 'Parakou', date: day));
      expect(offers.every((o) => o.pricePerSeat > 0 && o.originCity == 'Cotonou'), isTrue);

      // Le back ne renvoie pas l'identifiant des offres (voir docs/BACKEND_A_FAIRE.md) : la réservation se teste avec
      // l'identifiant d'une offre connue, donnée en WAMI_LIVE_OFFER_ID.
      final offerId = Platform.environment['WAMI_LIVE_OFFER_ID'];
      if (offerId == null) return;
      final known = offers.isEmpty ? null : offers.first;
      final offer = IntercityOffer(
        id: offerId,
        number: known?.number ?? '',
        vehicle: known?.vehicle ?? 'Confort',
        originCity: 'Cotonou',
        destinationCity: 'Parakou',
        departure: day,
        totalSeats: 4,
        availableSeats: 4,
        pricePerSeat: known?.pricePerSeat ?? 8000,
      );
      final booking = await intercity.book(offer, 2, IntercityPayment.cash);
      try {
        expect(booking.seats, 2);
        expect(booking.total, offer.pricePerSeat * 2);
        expect(booking.status, IntercityBookingStatus.confirmed);
        await expectLater(
          intercity.book(offer, 1, IntercityPayment.cash),
          throwsA(isA<BusinessRuleException>().having((e) => e.message, 'message', contains('déjà réservé'))),
        );
      } finally {
        expect(await intercity.cancel(booking.id), offer.pricePerSeat * 2);
      }
      await expectLater(
        intercity.cancel(booking.id),
        throwsA(
          isA<BusinessRuleException>().having((e) => e.message, 'message', contains('ne peut plus être annulée')),
        ),
      );
    },
    skip: skip,
  );

  test(
    'retrait : gains d’affilié lus à part, refus en français (minimum, plafond), demande réelle si WAMI_LIVE_WITHDRAW',
    () async {
      final wallets = WalletApiDataSource(api, session);
      final before = (await wallets.overview()).wallet;
      expect(before.affiliateBalance, greaterThanOrEqualTo(0));

      await expectLater(
        wallets
            .withdraw(const WithdrawRequest(amount: 200, method: WithdrawMethod.mobileMoney, phone: '+2290197123456')),
        throwsA(isA<BusinessRuleException>().having((e) => e.message, 'message', contains('Montant minimum'))),
      );
      await expectLater(
        wallets.withdraw(
          WithdrawRequest(
            amount: before.affiliateBalance + 5000,
            method: WithdrawMethod.mobileMoney,
            phone: '+2290197123456',
          ),
        ),
        throwsA(isA<BusinessRuleException>().having((e) => e.message, 'message', contains('gains d’affilié'))),
      );

      // Une vraie demande réserve le montant et bloque les suivantes : seulement sur demande explicite.
      if (Platform.environment['WAMI_LIVE_WITHDRAW'] == null || before.affiliateBalance < 1000) return;
      final receipt = await wallets.withdraw(
        const WithdrawRequest(amount: 1000, method: WithdrawMethod.mobileMoney, phone: '+2290197123456'),
      );
      expect(receipt.id, isNotEmpty);
      expect((await wallets.overview()).wallet.affiliateBalance, before.affiliateBalance - 1000);
      await expectLater(
        wallets
            .withdraw(const WithdrawRequest(amount: 1000, method: WithdrawMethod.mobileMoney, phone: '+2290197123456')),
        throwsA(isA<BusinessRuleException>().having((e) => e.message, 'message', contains('déjà en cours'))),
      );
    },
    skip: skip,
  );

  test(
    'profil : civilité, adresse, e-mail (ajout puis modification), code de vérification refusé en français',
    () async {
      final account = AccountApiDataSource(api, session);
      final before = await account.profile();

      final withGender = await account.setGender(before.gender == Gender.male ? Gender.female : Gender.male);
      expect(withGender.gender, isNot(before.gender));
      expect((await account.setGender(before.gender ?? Gender.female)).gender, before.gender ?? Gender.female);

      final withAddress = await account.setAddress(
        const PostalAddress(city: 'Cotonou', quarter: 'Akpakpa', street: 'Avenue Steinmetz'),
      );
      expect(withAddress.address?.summary, 'Avenue Steinmetz, Akpakpa, Cotonou');

      // Le profil du back ne renvoie pas l'e-mail : l'ajout est tenté, puis la modification si un e-mail existe déjà.
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final saved = await account.updateProfile(before.copyWith(email: 'live$stamp@exemple.bj'));
      expect(saved.email, 'live$stamp@exemple.bj');
      expect(saved.emailVerified, isFalse);

      await expectLater(
        account.verify(VerificationKind.email, '000000'),
        throwsA(isA<BusinessRuleException>().having((e) => e.message, 'message', contains('Code invalide ou expiré'))),
      );
      await account.resendVerification();
    },
    skip: skip,
  );

  test(
    'temps réel : le WebSocket accepte le jeton de la session et refuse un faux',
    () async {
      Future<bool> connects(CurrentSession s) async {
        final signals = SocketIoRealtimeSignals(AppConfig(apiBaseUrl: url!, useFakeBackend: false), s);
        final sub = signals.ride('test').listen((_) {});
        try {
          for (var i = 0; i < 50 && !signals.isConnected; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          return signals.isConnected;
        } finally {
          await sub.cancel();
        }
      }

      expect(await connects(session), isTrue);
      final forged = CurrentSession()
        ..set(AuthSession.fromJson({...session.value!.toJson(), 'token': 'faux.jeton.signature'}));
      expect(await connects(forged), isFalse);
    },
    skip: skip,
  );
}

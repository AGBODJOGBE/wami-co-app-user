import 'package:flutter_test/flutter_test.dart';
import 'package:wami/app.dart';
import 'package:wami/app/di/injection.dart';
import 'package:wami/app/router/app_router.dart';
import 'package:wami/core/auth/auth_session.dart';
import 'package:wami/core/auth/current_session.dart';
import 'package:wami/core/auth/session_store.dart';
import 'package:wami/core/config/app_config.dart';
import 'package:wami/core/data/fake_backend.dart';
import 'package:wami/core/di/service_locator.dart';
import 'package:wami/core/error/exceptions.dart';
import 'package:wami/core/utils/load_status.dart';
import 'package:wami/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:wami/features/intercity/data/datasources/intercity_data_sources.dart';
import 'package:wami/features/intercity/data/repositories/intercity_repository_impl.dart';
import 'package:wami/features/intercity/domain/entities/intercity.dart';
import 'package:wami/features/intercity/domain/usecases/intercity_usecases.dart';
import 'package:wami/features/intercity/presentation/cubit/intercity_cubit.dart';

import '../../support/stub_server.dart';

Map<String, dynamic> _offer({String? id = 'o1', int available = 3, Map<String, dynamic>? extra}) => {
      if (id != null) 'id': id,
      'offerNumber': 'WM-OF-ABCD2345',
      'vehicleType': 'CONFORT',
      'originCity': 'Cotonou',
      'destinationCity': 'Parakou',
      'originLocation': {'latitude': 6.36, 'longitude': 2.41, 'address': 'Gare de Cotonou'},
      'destinationLocation': {'latitude': 9.33, 'longitude': 2.63, 'address': ''},
      'departureTime': '2026-11-06T07:00:00.000Z',
      'estimatedArrivalTime': '2026-11-06T11:00:00.000Z',
      'totalSeats': 4,
      'availableSeats': available,
      'pricePerSeat': 8000,
      'platformShareRate': 0.15,
      'driverId': 'drv',
      'waypoints': [
        {
          'location': {'latitude': 7.1, 'longitude': 1.9, 'address': 'Dassa'},
          'city': 'Dassa-Zoumè',
        },
      ],
      'description': 'Clim, bagages acceptés',
      ...?extra,
    };

IntercityApiDataSource _source(StubServer server) {
  final session = CurrentSession()
    ..set(
      const AuthSession(
        token: 't',
        userId: 'u',
        passengerId: 'p',
        walletId: 'w',
        phone: '+2290197123456',
        firstName: 'Awa',
        lastName: 'Dossou',
      ),
    );
  return IntercityApiDataSource(server.client(session: session));
}

IntercityQuery get _query => IntercityQuery(from: 'Cotonou', to: 'Parakou', date: DateTime(2026, 11, 6), seats: 2);

void main() {
  group('source de données', () {
    late StubServer server;
    late IntercityApiDataSource source;

    setUp(() {
      server = StubServer();
      source = _source(server);
    });

    test('recherche : paramètres envoyés, offre lue (étapes, trajet, aucune donnée financière)', () async {
      server.on('GET /api/passenger/offers', {
        'success': true,
        'data': [_offer()],
      });
      final offers = await source.search(_query);

      expect(server.last('GET /api/passenger/offers')!.queryParameters, {
        'originCity': 'Cotonou',
        'destinationCity': 'Parakou',
        'date': '2026-11-06',
        'minSeats': 2,
      });
      final o = offers.single;
      expect(o.id, 'o1');
      expect(o.number, 'WM-OF-ABCD2345');
      expect(o.vehicle, 'Confort');
      expect(o.pricePerSeat, 8000);
      expect(o.availableSeats, 3);
      expect(o.stops, ['Dassa-Zoumè']);
      expect(o.originAddress, 'Gare de Cotonou');
      expect(o.destinationAddress, isNull, reason: 'adresse vide ignorée');
      expect(o.duration, const Duration(hours: 4));
      expect(o.bookable, isTrue);
    });

    test('sans identifiant dans la réponse, l’offre s’affiche mais ne se réserve pas', () async {
      server.on('GET /api/passenger/offers', {
        'success': true,
        'data': [_offer(id: null)],
      });
      final o = (await source.search(_query)).single;
      expect(o.id, isNull);
      expect(o.bookable, isFalse);
    });

    test('réservation : corps envoyé, réservation lue', () async {
      server.on('POST /api/passenger/offers/o1/book', {
        'success': true,
        'data': {
          'bookingId': 'd9238a2b-836e-41a4-8534-870614778486',
          'offerId': 'o1',
          'seatsBooked': 2,
          'totalPrice': 16000,
          'paymentMethod': 'WALLET',
          'status': 'CONFIRMED',
          'availableSeatsLeft': 1,
        },
      });
      final offer = IntercityApiDataSource.offer(_offer());
      final booking = await source.book(offer, 2, IntercityPayment.wallet);

      expect(server.last('POST /api/passenger/offers/o1/book')!.data, {'seatsBooked': 2, 'paymentMethod': 'WALLET'});
      expect(booking.total, 16000);
      expect(booking.seats, 2);
      expect(booking.status, IntercityBookingStatus.confirmed);
      expect(booking.reference, 'D9238A2B');
    });

    test('refus du back traduits en français', () async {
      final offer = IntercityApiDataSource.offer(_offer());
      for (final (english, french) in [
        ('Offer not found.', 'Ce trajet n’existe plus.'),
        ('You already have an active booking on this offer.', 'Vous avez déjà réservé sur ce trajet.'),
        ('Only 1 seat(s) available, requested 3', 'Il ne reste que 1 place(s) sur ce trajet.'),
        ('Offer is no longer available (status: STARTED).', 'Ce trajet n’est plus disponible.'),
      ]) {
        final s = StubServer()
          ..on('POST /api/passenger/offers/o1/book', {'success': false, 'error': english}, status: 400);
        await expectLater(
          _source(s).book(offer, 1, IntercityPayment.cash),
          throwsA(isA<BusinessRuleException>().having((e) => e.message, 'message', french)),
          reason: english,
        );
      }
    });

    test('annulation : montant remboursé lu, deuxième annulation refusée en français', () async {
      server
        ..on('DELETE /api/passenger/bookings/b1/cancel', {
          'success': true,
          'data': {'bookingId': 'b1', 'status': 'CANCELLED_BY_PASSENGER', 'refundAmount': 16000},
        })
        ..on(
          'DELETE /api/passenger/bookings/b1/cancel',
          {'success': false, 'error': 'Cannot cancel a booking in status CANCELLED_BY_PASSENGER.'},
          status: 400,
        );
      expect(await source.cancel('b1'), 16000);
      await expectLater(
        source.cancel('b1'),
        throwsA(
          isA<BusinessRuleException>()
              .having((e) => e.message, 'message', 'Cette réservation ne peut plus être annulée.'),
        ),
      );
    });
  });

  group('cas d’usage', () {
    late IntercityRepositoryImpl repo;

    setUp(() {
      const config = AppConfig(apiBaseUrl: '', useFakeBackend: true, fakeLatency: Duration.zero);
      repo = IntercityRepositoryImpl(IntercityFakeDataSource(const FakeBackend(config)));
    });

    test('recherche : villes identiques et date passée refusées avant tout appel', () async {
      final search = SearchIntercityOffers(repo);
      final same = await search(IntercityQuery(from: 'Cotonou', to: ' cotonou ', date: DateTime.now()));
      final past = await search(IntercityQuery(from: 'Cotonou', to: 'Parakou', date: DateTime(2020)));
      expect(same.isOk, isFalse);
      expect(past.isOk, isFalse);
    });

    test('recherche : seulement les trajets avec assez de places, du plus tôt au plus tard', () async {
      final result = await SearchIntercityOffers(repo)(
        IntercityQuery(from: 'Cotonou', to: 'Parakou', date: DateTime.now().add(const Duration(days: 1)), seats: 2),
      );
      final offers = result.valueOrNull!;
      expect(offers.every((o) => o.availableSeats >= 2), isTrue);
      expect(offers.length, 2, reason: 'l’offre à une seule place est écartée');
      expect(offers.first.departure.isBefore(offers.last.departure), isTrue);
    });

    test('réservation : sans identifiant ou avec trop de places, refusée sans appel', () async {
      final book = BookIntercityOffer(repo);
      final noId = IntercityApiDataSource.offer(_offer(id: null));
      final full = IntercityApiDataSource.offer(_offer(available: 1));
      expect((await book(BookIntercityParams(offer: noId, seats: 1, payment: IntercityPayment.cash))).isOk, isFalse);
      expect((await book(BookIntercityParams(offer: full, seats: 2, payment: IntercityPayment.cash))).isOk, isFalse);
    });
  });

  group('cubit', () {
    late IntercityCubit cubit;

    setUp(() {
      const config = AppConfig(apiBaseUrl: '', useFakeBackend: true, fakeLatency: Duration.zero);
      final repo = IntercityRepositoryImpl(IntercityFakeDataSource(const FakeBackend(config)));
      cubit = IntercityCubit(
        search: SearchIntercityOffers(repo),
        book: BookIntercityOffer(repo),
        cancel: CancelIntercityBooking(repo),
      );
    });

    tearDown(() => cubit.close());

    test('recherche, choix, réservation puis annulation avec remboursement', () async {
      cubit.setSeats(2);
      await cubit.search();
      expect(cubit.state.searchStatus, LoadStatus.ready);
      expect(cubit.state.offers, isNotEmpty);

      cubit.select(cubit.state.offers.first);
      expect(cubit.state.seats, 2);
      expect(cubit.state.total, 16000);
      cubit.setBookedSeats(99);
      expect(cubit.state.seats, cubit.state.selected!.availableSeats, reason: 'jamais plus que les places libres');
      cubit.setBookedSeats(2);

      await cubit.book();
      expect(cubit.state.bookingStatus, LoadStatus.ready);
      expect(cubit.state.booking!.status, IntercityBookingStatus.confirmed);

      await cubit.cancel();
      expect(cubit.state.booking!.status, IntercityBookingStatus.cancelled);
      expect(cubit.state.booking!.refund, 8000);

      // Une réservation déjà annulée n'est pas annulée une deuxième fois.
      await cubit.cancel();
      expect(cubit.state.cancelStatus, LoadStatus.ready);
    });
  });

  testWidgets('parcours à l’écran : recherche → trajet → réservation → annulation', (tester) async {
    final store = InMemorySessionStore();
    await store.write(
      const AuthSession(
        token: 't',
        userId: 'u',
        passengerId: 'p',
        walletId: 'w',
        phone: '+2290197123456',
        firstName: 'Awa',
        lastName: 'Dossou',
      ),
    );
    await configureDependencies(
      const AppConfig(apiBaseUrl: '', useFakeBackend: true, fakeLatency: Duration.zero),
      sessionStore: store,
    );
    await sl<AuthCubit>().restore();
    await tester.pumpWidget(const WamiApp());
    await tester.pumpAndSettle();

    // Le service est sur l'accueil.
    expect(find.text('Interurbain'), findsOneWidget);
    sl<AppRouter>().config.go('/intercity');
    await tester.pumpAndSettle();
    expect(find.text('Trajets interurbains'), findsOneWidget);

    // Choix d'une autre ville d'arrivée dans la liste.
    await tester.tap(find.text('Parakou'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bohicon'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rechercher'));
    await tester.pumpAndSettle();
    expect(find.text('Cotonou → Bohicon'), findsOneWidget);
    expect(find.textContaining('place(s) libre(s)'), findsWidgets);

    // Premier trajet : détail, paiement en espèces, réservation.
    await tester.tap(find.textContaining('Étapes : Dassa-Zoumè'));
    await tester.pumpAndSettle();
    expect(find.text('PAIEMENT'), findsOneWidget);
    await tester.ensureVisible(find.text('Espèces'));
    await tester.tap(find.text('Espèces'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réserver'));
    await tester.pumpAndSettle();
    expect(find.text('C’est réservé !'), findsOneWidget);
    expect(find.text('CODE DE RÉSERVATION'), findsOneWidget);

    // Annulation confirmée.
    await tester.tap(find.text('Annuler la réservation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler la réservation').last);
    await tester.pumpAndSettle();
    expect(find.text('Réservation annulée'), findsOneWidget);
    expect(find.textContaining('remboursés'), findsOneWidget);
  });
}

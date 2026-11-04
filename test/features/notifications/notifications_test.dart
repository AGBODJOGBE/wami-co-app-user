import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wami/app.dart';
import 'package:wami/app/di/injection.dart';
import 'package:wami/core/auth/auth_session.dart';
import 'package:wami/core/auth/session_store.dart';
import 'package:wami/core/config/app_config.dart';
import 'package:wami/core/di/service_locator.dart';
import 'package:wami/core/error/exceptions.dart';
import 'package:wami/core/utils/result.dart';
import 'package:wami/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:wami/features/notifications/data/datasources/notifications_data_sources.dart';
import 'package:wami/features/notifications/domain/entities/app_notification.dart';
import 'package:wami/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:wami/features/notifications/domain/usecases/notifications_usecases.dart';
import 'package:wami/features/notifications/presentation/cubit/notifications_cubit.dart';

import '../../support/stub_server.dart';

Map<String, dynamic> _n(
  String id,
  String type,
  String createdAt, {
  bool read = false,
  String? entity,
  String channel = 'PUSH',
}) =>
    {
      'id': id,
      'type': type,
      'channel': channel,
      'message': 'message $id',
      'isRead': read,
      'relatedEntity': entity == null ? null : {'type': 'RIDE', 'id': entity},
      'createdAt': createdAt,
    };

Map<String, dynamic> _ok(Object data) => {'success': true, 'data': data};

AppNotification _entity(String id, {bool read = false, DateTime? at}) => AppNotification(
      id: id,
      type: 'RIDE_COMPLETED',
      message: 'm$id',
      createdAt: at ?? DateTime(2026, 11, 4, 10),
      isRead: read,
    );

class _Repo implements NotificationsRepository {
  _Repo(this.pages);
  final List<NotificationPage> pages;
  final marked = <String>[];

  @override
  Future<Result<NotificationPage>> getPage(int page) async => Ok(pages[page - 1]);

  @override
  Future<Result<void>> markAsRead(String id) async {
    marked.add(id);
    return const Ok(null);
  }
}

void main() {
  group('source de données', () {
    late StubServer server;
    late NotificationsApiDataSource source;

    setUp(() {
      server = StubServer();
      source = NotificationsApiDataSource(server.client());
    });

    test('page demandée sans jamais envoyer recipientId', () async {
      server.on(
        'GET /api/notifications',
        _ok({
          'notifications': [_n('a', 'WALLET_RECHARGED', '2026-11-04T10:00:00.000Z')],
          'total': 45,
          'page': 2,
          'limit': 20,
          'totalPages': 3,
        }),
      );
      final page = await source.page(2);
      final query = server.last('GET /api/notifications')!.queryParameters;
      expect(query, {'page': 2, 'limit': 20});
      expect(query.containsKey('recipientId'), isFalse);
      expect(page.page, 2);
      expect(page.totalPages, 3);
      expect(page.hasMore, isTrue);
      expect(page.items.single.title, 'Portefeuille rechargé');
    });

    test('un événement notifié sur plusieurs canaux n’apparaît qu’une fois', () async {
      server.on(
        'GET /api/notifications',
        _ok({
          'notifications': [
            _n('push', 'DRIVER_ASSIGNED', '2026-11-04T10:00:05.000Z', entity: 'r1'),
            _n('ws', 'DRIVER_ASSIGNED', '2026-11-04T10:00:04.000Z', entity: 'r1', channel: 'WEBSOCKET', read: true),
            _n('sms', 'DRIVER_ASSIGNED', '2026-11-04T10:00:03.000Z', entity: 'r1', channel: 'SMS'),
            // même type, autre course : à garder
            _n('autre', 'DRIVER_ASSIGNED', '2026-11-04T09:00:00.000Z', entity: 'r2'),
            // même course mais deux minutes plus tard : un autre événement
            _n('tard', 'DRIVER_ASSIGNED', '2026-11-04T10:02:30.000Z', entity: 'r1'),
          ],
          'total': 5,
          'page': 1,
          'limit': 20,
          'totalPages': 1,
        }),
      );
      final items = (await source.page(1)).items;
      expect(items.map((n) => n.id), ['push', 'autre', 'tard']);
    });

    test('un doublon non lu rend l’événement non lu', () {
      final read = AppNotification(
        id: 'a',
        type: 'RIDE_COMPLETED',
        message: 'm',
        createdAt: DateTime.utc(2026, 11, 4, 10),
        isRead: true,
        entityId: 'r',
      );
      final unread = AppNotification(
        id: 'b',
        type: 'RIDE_COMPLETED',
        message: 'm',
        createdAt: DateTime.utc(2026, 11, 4, 10),
        entityId: 'r',
      );
      expect(NotificationsApiDataSource.collapse([read, unread]).single.isRead, isFalse);
    });

    test('marquer comme lue', () async {
      server.on('PATCH /api/notifications/a/read', _ok({'message': 'ok'}));
      await source.markAsRead('a');
      expect(server.count('PATCH /api/notifications/a/read'), 1);
    });

    for (final c in [(404, 'NOT_FOUND'), (403, 'FORBIDDEN')]) {
      test('marquer une notification ${c.$2} n’est pas une panne', () async {
        server.on(
          'PATCH /api/notifications/x/read',
          {
            'success': false,
            'error': {'message': 'Access denied', 'code': c.$2},
          },
          status: c.$1,
        );
        await source.markAsRead('x');
      });
    }

    test('une vraie panne reste une erreur', () {
      server.on('PATCH /api/notifications/x/read', {'success': false, 'error': 'boom'}, status: 500);
      expect(source.markAsRead('x'), throwsA(isA<ServerException>()));
    });
  });

  group('catégories et titres', () {
    test('catégories', () {
      expect(_type('DRIVER_ASSIGNED').category, NotificationCategory.ride);
      expect(_type('RIDE_COMPLETED').category, NotificationCategory.ride);
      expect(_type('B2C_DELIVERY_DISPATCHED').category, NotificationCategory.delivery);
      expect(_type('WALLET_RECHARGED').category, NotificationCategory.wallet);
      expect(_type('P2P_TRANSFER_RECEIVED').category, NotificationCategory.wallet);
      expect(_type('CHAT_MESSAGE').category, NotificationCategory.other);
    });

    test('type inconnu : titre générique', () => expect(_type('TYPE_INCONNU').title, 'Notification'));
  });

  group('état', () {
    late _Repo repo;
    late NotificationsCubit cubit;

    setUp(() {
      repo = _Repo([
        NotificationPage(items: [_entity('a'), _entity('b', read: true), _entity('c')], page: 1, totalPages: 2),
        NotificationPage(items: [_entity('c'), _entity('d')], page: 2, totalPages: 2),
      ]);
      cubit = NotificationsCubit(GetNotifications(repo), MarkNotificationRead(repo));
    });

    tearDown(() => cubit.close());

    test('chargement et compteur de non lues', () async {
      await cubit.load();
      expect(cubit.state.items.map((n) => n.id), ['a', 'b', 'c']);
      expect(cubit.state.unreadCount, 2);
      expect(cubit.state.hasMore, isTrue);
    });

    test('page suivante sans doublon', () async {
      await cubit.load();
      await cubit.loadMore();
      expect(cubit.state.items.map((n) => n.id), ['a', 'b', 'c', 'd']);
      expect(cubit.state.hasMore, isFalse);
      // Plus de page : rien de plus n'est demandé.
      await cubit.loadMore();
      expect(cubit.state.items, hasLength(4));
    });

    test('lue tout de suite à l’écran puis signalée au back', () async {
      await cubit.load();
      final done = cubit.markRead('a');
      expect(cubit.state.unreadCount, 1);
      await done;
      expect(repo.marked, ['a']);
      // Déjà lue : pas de second appel.
      await cubit.markRead('b');
      expect(repo.marked, ['a']);
    });

    test('déconnexion : tout est vidé', () async {
      await cubit.load();
      cubit.reset();
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.unreadCount, 0);
    });
  });

  testWidgets('cloche de l’accueil, liste groupée par jour et lecture', (tester) async {
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

    // Deux notifications non lues : la pastille affiche 2.
    expect(find.byTooltip('Notifications, 2 non lues'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byTooltip('Notifications, 2 non lues'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsWidgets);
    expect(find.text('2 non lues'), findsOneWidget);
    expect(find.text('Chauffeur trouvé'), findsOneWidget);
    expect(find.text('Portefeuille rechargé'), findsOneWidget);
    expect(find.text('Course terminée'), findsOneWidget);

    // Ouvrir une notification la marque lue.
    await tester.tap(find.text('Chauffeur trouvé'));
    await tester.pumpAndSettle();
    expect(find.text('1 non lue'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}

AppNotification _type(String type) =>
    AppNotification(id: 'x', type: type, message: 'm', createdAt: DateTime(2026, 11, 4));

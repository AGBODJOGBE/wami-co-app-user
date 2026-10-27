import 'package:flutter_test/flutter_test.dart';
import 'package:wami/core/auth/auth_session.dart';
import 'package:wami/core/auth/current_session.dart';
import 'package:wami/core/error/exceptions.dart';
import 'package:wami/features/wallet/data/datasources/wallet_data_sources.dart';
import 'package:wami/features/wallet/domain/entities/wallet.dart';

import '../../support/stub_server.dart';

const _balance = '/api/wallets/w1/balance';
const _history = '/api/wallets/w1/transactions';

Map<String, dynamic> _tx(String id, String type, String direction, int amount, {String status = 'COMPLETED'}) => {
      'id': id,
      'type': type,
      'direction': direction,
      'amount': amount,
      'description': 'desc $id',
      'status': status,
      'createdAt': '2026-10-24T08:00:00.000Z',
    };

void main() {
  late StubServer server;
  late WalletApiDataSource wallet;

  setUp(() {
    server = StubServer();
    final session = CurrentSession()
      ..set(
        const AuthSession(
          token: 't',
          userId: 'u',
          passengerId: 'p',
          walletId: 'w1',
          phone: '+2290197123456',
          firstName: 'Awa',
          lastName: 'Dossou',
        ),
      );
    wallet = WalletApiDataSource(
      server.client(session: session),
      session,
      pollEvery: Duration.zero,
      pollFor: const Duration(seconds: 2),
    );
    server.on('GET $_balance', {
      'success': true,
      'data': {'mainBalance': 8000, 'bonusBalance': 500, 'affiliateBalance': 9999, 'totalBalance': 8500},
    });
    server.on('GET $_history', {
      'success': true,
      'data': {
        'transactions': [
          _tx('a', 'RECHARGE', 'CREDIT', 10000),
          _tx('b', 'RIDE_PAYMENT', 'DEBIT', 2500),
          _tx('c', 'DELIVERY_PAYMENT', 'DEBIT', 1500),
          _tx('d', 'ADJUSTMENT', 'DEBIT', 1000),
          _tx('e', 'ADJUSTMENT', 'CREDIT', 700),
          _tx('f', 'RECHARGE', 'CREDIT', 5000, status: 'PENDING'),
        ],
      },
    });
  });

  test('solde dépensable (sans les gains d’affilié) et historique signé', () async {
    final o = await wallet.overview();
    expect(o.wallet.balance, 8500);
    expect(o.wallet.holder, 'Awa Dossou');
    // La recharge encore en attente n'apparaît pas.
    expect(o.transactions.map((t) => t.id), ['a', 'b', 'c', 'd', 'e']);
    expect(o.transactions.map((t) => t.amount), [10000, -2500, -1500, -1000, 700]);
    expect(o.transactions.map((t) => t.kind), [
      TransactionKind.topUp,
      TransactionKind.ride,
      TransactionKind.delivery,
      TransactionKind.transferOut,
      TransactionKind.transferIn,
    ]);
  });

  test('recharge : suit le paiement jusqu’à sa validation puis relit le solde', () async {
    server
      ..on('POST /api/payment/recharge', {'paymentIntentId': 'pi1', 'status': 'PROCESSING'}, status: 202)
      ..on('GET /api/payment/status/pi1', {'status': 'PROCESSING'})
      ..on('GET /api/payment/status/pi1', {'status': 'COMPLETED'});

    await wallet.topUp(5000, '+2290197123456');

    expect(server.last('POST /api/payment/recharge')!.data, {
      'walletId': 'w1',
      'amount': 5000,
      'phone': '+2290197123456',
      'description': 'Recharge WAMI',
    });
    expect(server.count('GET /api/payment/status/pi1'), 2);
    expect(server.count('GET $_balance'), 1);
  });

  test('recharge refusée par l’opérateur', () async {
    server
      ..on('POST /api/payment/recharge', {'paymentIntentId': 'pi2', 'status': 'PROCESSING'}, status: 202)
      ..on('GET /api/payment/status/pi2', {'status': 'FAILED', 'failureReason': 'timeout'});
    expect(
      () => wallet.topUp(5000, '+2290197123456'),
      throwsA(isA<BusinessRuleException>().having((e) => e.code, 'code', 'payment_failed')),
    );
  });

  test('recharge : aucun opérateur disponible (502)', () async {
    server.on(
      'POST /api/payment/recharge',
      {'paymentIntentId': 'pi4', 'status': 'FAILED', 'error': 'All providers failed'},
      status: 502,
    );
    expect(
      () => wallet.topUp(5000, '+2290197123456'),
      throwsA(isA<BusinessRuleException>().having((e) => e.code, 'code', 'payment_failed')),
    );
  });

  test('recharge jamais confirmée : message d’attente, pas d’échec', () async {
    server
      ..on('POST /api/payment/recharge', {'paymentIntentId': 'pi3', 'status': 'PROCESSING'}, status: 202)
      ..on('GET /api/payment/status/pi3', {'status': 'PROCESSING'});
    final short = WalletApiDataSource(
      server.client(),
      CurrentSession()
        ..set(
          const AuthSession(
            token: 't',
            userId: 'u',
            passengerId: 'p',
            walletId: 'w1',
            phone: '+1',
            firstName: '',
            lastName: '',
          ),
        ),
      pollEvery: Duration.zero,
      pollFor: const Duration(milliseconds: 50),
    );
    expect(
      () => short.topUp(5000, '+2290197123456'),
      throwsA(isA<BusinessRuleException>().having((e) => e.code, 'code', 'payment_pending')),
    );
  });

  group('transfert', () {
    test('envoie le numéro du destinataire', () async {
      server.on('POST /api/wallets/w1/transfer', {
        'success': true,
        'data': {'sentAmount': 1000},
      });
      await wallet.transfer('+2290197000001', 1000, ' pour le taxi ');
      expect(server.last('POST /api/wallets/w1/transfer')!.data, {
        'recipientPhone': '+2290197000001',
        'amount': 1000,
        'note': 'pour le taxi',
      });
    });

    test('solde insuffisant', () async {
      server.on(
        'POST /api/wallets/w1/transfer',
        {'success': false, 'error': 'Insufficient balance — required: 9000 FCFA, available: 100 FCFA'},
        status: 400,
      );
      expect(
        () => wallet.transfer('+2290197000001', 9000, null),
        throwsA(isA<BusinessRuleException>().having((e) => e.code, 'code', 'insufficient_funds')),
      );
    });

    test('destinataire inconnu, en français', () async {
      server.on(
        'POST /api/wallets/w1/transfer',
        {'success': false, 'error': 'Wallet not found: No user found with phone "+229"'},
        status: 404,
      );
      expect(
        () => wallet.transfer('+2290197000001', 100, null),
        throwsA(isA<BusinessRuleException>().having((e) => e.message, 'message', contains('Aucun compte WAMI'))),
      );
    });
  });
}

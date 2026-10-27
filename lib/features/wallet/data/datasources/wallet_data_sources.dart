import '../../../../core/auth/current_session.dart';
import '../../../../core/data/fake_backend.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/wallet.dart';

abstract interface class WalletRemoteDataSource {
  Future<WalletOverview> overview();
  Future<WalletOverview> topUp(int amount, String phone);
  Future<WalletOverview> transfer(String recipientPhone, int amount, String? note);
}

/// Routes `/api/wallets/:walletId/*` et `/api/payment/status/*` du back wami-co.
///
/// - Le solde dépensable est `totalBalance` (bonus et parrainage compris, gains d'affilié exclus).
/// - La recharge est asynchrone : le serveur renvoie 202 puis l'opérateur demande la confirmation
///   au client ; on suit l'état du paiement jusqu'à son terme.
class WalletApiDataSource implements WalletRemoteDataSource {
  WalletApiDataSource(
    this._api,
    this._session, {
    this.pollEvery = const Duration(seconds: 3),
    this.pollFor = const Duration(minutes: 2),
  });

  final ApiClient _api;
  final CurrentSession _session;
  final Duration pollEvery;
  final Duration pollFor;

  String get _base => '/api/wallets/${_session.walletId}';

  @override
  Future<WalletOverview> overview() async {
    final results = await Future.wait([
      _api.get('$_base/balance'),
      _api.get('$_base/transactions', query: {'limit': 30}),
    ]);
    return WalletOverview(
      wallet: Wallet(
        balance: (results[0]['totalBalance'] as num).toInt(),
        // Pas de programme de points côté back pour l'instant.
        points: 0,
        holder: _session.value?.fullName ?? '',
      ),
      transactions: (results[1]['transactions'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .where((t) => t['status'] == 'COMPLETED')
          .map(_transaction)
          .toList(),
    );
  }

  /// Passe par le module paiement (`/api/payment/recharge`) : contrairement à `/api/wallets/:id/recharge`,
  /// il renvoie l'identifiant du paiement, indispensable pour le suivre.
  @override
  Future<WalletOverview> topUp(int amount, String phone) async {
    final Map<String, dynamic> started;
    try {
      started = await _api.post(
        '/api/payment/recharge',
        body: {'walletId': _session.walletId, 'amount': amount, 'phone': phone, 'description': 'Recharge WAMI'},
      );
    } on ServerException catch (e) {
      // 502 : aucun opérateur n'a pu lancer le paiement.
      if (e.statusCode == 502) {
        throw const BusinessRuleException(
            'payment_failed', 'Paiement impossible pour le moment. Réessayez dans un instant.',);
      }
      rethrow;
    }
    await _waitForPayment(started['paymentIntentId'] as String);
    return overview();
  }

  Future<void> _waitForPayment(String intentId) async {
    final deadline = DateTime.now().add(pollFor);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(pollEvery);
      final status = await _api.get('/api/payment/status/$intentId');
      switch (status['status']) {
        case 'COMPLETED':
          return;
        case 'FAILED' || 'EXPIRED':
          throw const BusinessRuleException(
            'payment_failed',
            'Le paiement n’a pas abouti. Vérifiez votre solde Mobile Money et réessayez.',
          );
      }
    }
    throw const BusinessRuleException(
      'payment_pending',
      'Paiement en attente de confirmation. Votre solde sera mis à jour dès qu’il est validé.',
    );
  }

  @override
  Future<WalletOverview> transfer(String recipientPhone, int amount, String? note) async {
    try {
      await _api.post(
        '$_base/transfer',
        body: {
          'recipientPhone': recipientPhone,
          'amount': amount,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
      );
    } on BusinessRuleException catch (e) {
      throw _frenchTransferError(e);
    }
    return overview();
  }

  /// Le back répond en anglais : on traduit les refus que l'utilisateur peut rencontrer.
  BusinessRuleException _frenchTransferError(BusinessRuleException e) {
    final m = (e.message ?? '').toLowerCase();
    if (m.contains('insufficient balance')) return const BusinessRuleException('insufficient_funds');
    if (m.contains('no user found') || m.contains('not found')) {
      return const BusinessRuleException('rejected', 'Aucun compte WAMI ne correspond à ce numéro.');
    }
    if (m.contains('yourself')) {
      return const BusinessRuleException('rejected', 'Vous ne pouvez pas vous envoyer de l’argent à vous-même.');
    }
    if (m.contains('only transfer money to other passengers')) {
      return const BusinessRuleException('rejected', 'Vous pouvez envoyer de l’argent à un autre passager WAMI.');
    }
    if (m.contains('disabled')) {
      return const BusinessRuleException('rejected', 'Les transferts sont momentanément indisponibles.');
    }
    return e;
  }

  WalletTransaction _transaction(Map<String, dynamic> t) {
    final amount = (t['amount'] as num).toInt();
    return WalletTransaction(
      id: t['id'] as String,
      label: t['description'] as String? ?? '',
      date: DateTime.parse(t['createdAt'] as String).toLocal(),
      amount: t['direction'] == 'DEBIT' ? -amount : amount,
      kind: _kind(t['type'] as String? ?? '', t['direction'] as String? ?? ''),
    );
  }

  TransactionKind _kind(String type, String direction) {
    if (type.startsWith('RIDE') || type.startsWith('SCHEDULED_RIDE') || type.startsWith('CANCELLATION')) {
      return TransactionKind.ride;
    }
    if (type.startsWith('DELIVERY') || type.startsWith('SUBSCRIPTION')) return TransactionKind.delivery;
    if (type == 'RECHARGE') return TransactionKind.topUp;
    // Transferts entre passagers : le back ne leur donne pas de type dédié, seule la direction les distingue.
    return direction == 'DEBIT' ? TransactionKind.transferOut : TransactionKind.transferIn;
  }
}

/// Portefeuille simulé, avec un vrai solde en mémoire.
class WalletFakeDataSource implements WalletRemoteDataSource {
  WalletFakeDataSource(this._fake, this._session);
  final FakeBackend _fake;
  final CurrentSession _session;

  int _balance = 25000;
  int _seq = 0;
  late final List<WalletTransaction> _txs = [
    WalletTransaction(
      id: 't1',
      label: 'Course Confort',
      date: DateTime.now().subtract(const Duration(hours: 2)),
      amount: -2500,
      kind: TransactionKind.ride,
    ),
    WalletTransaction(
      id: 't2',
      label: 'Recharge Mobile Money',
      date: DateTime.now().subtract(const Duration(days: 1)),
      amount: 10000,
      kind: TransactionKind.topUp,
    ),
    WalletTransaction(
      id: 't3',
      label: 'Livraison colis',
      date: DateTime.now().subtract(const Duration(days: 3)),
      amount: -1500,
      kind: TransactionKind.delivery,
    ),
  ];

  WalletOverview _snapshot() => WalletOverview(
        wallet: Wallet(balance: _balance, points: 320, holder: _session.value?.fullName ?? 'Gilexe AGBODJOGBE'),
        transactions: List.unmodifiable(_txs),
      );

  @override
  Future<WalletOverview> overview() async {
    await _fake.latency();
    return _snapshot();
  }

  @override
  Future<WalletOverview> topUp(int amount, String phone) async {
    await _fake.latency(2);
    _balance += amount;
    _txs.insert(
      0,
      WalletTransaction(
        id: 'n${_seq++}',
        label: 'Recharge Mobile Money',
        date: DateTime.now(),
        amount: amount,
        kind: TransactionKind.topUp,
      ),
    );
    return _snapshot();
  }

  @override
  Future<WalletOverview> transfer(String recipientPhone, int amount, String? note) async {
    await _fake.latency(1.5);
    if (amount > _balance) throw const BusinessRuleException('insufficient_funds');
    _balance -= amount;
    _txs.insert(
      0,
      WalletTransaction(
        id: 'n${_seq++}',
        label: 'Transfert à $recipientPhone',
        date: DateTime.now(),
        amount: -amount,
        kind: TransactionKind.transferOut,
      ),
    );
    return _snapshot();
  }
}

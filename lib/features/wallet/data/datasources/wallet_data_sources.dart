import '../../../../core/data/fake_backend.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/wallet.dart';

abstract interface class WalletRemoteDataSource {
  Future<WalletOverview> overview();
  Future<List<TopUpSource>> sources();
  Future<List<Beneficiary>> beneficiaries();
  Future<WalletOverview> topUp(int amount, String sourceId);
  Future<WalletOverview> transfer(String beneficiaryId, int amount, String? note);
}

WalletOverview _overview(Map<String, dynamic> j) {
  final w = j['wallet'] as Map<String, dynamic>;
  return WalletOverview(
    wallet: Wallet(balance: w['balance'] as int, points: w['points'] as int? ?? 0, holder: w['holder'] as String),
    transactions: (j['transactions'] as List<dynamic>).cast<Map<String, dynamic>>().map((t) {
      return WalletTransaction(
        id: t['id'] as String,
        label: t['label'] as String,
        date: DateTime.parse(t['date'] as String),
        amount: t['amount'] as int,
        kind: TransactionKind.values.byName(t['kind'] as String),
      );
    }).toList(),
  );
}

/// Endpoints à valider ; paiement réel via l'agrégateur retenu (FedaPay ?) — à valider.
class WalletApiDataSource implements WalletRemoteDataSource {
  const WalletApiDataSource(this._api);
  final ApiClient _api;

  List<Map<String, dynamic>> _items(Map<String, dynamic> j) =>
      (j['items'] as List<dynamic>).cast<Map<String, dynamic>>();

  @override
  Future<WalletOverview> overview() async => _overview(await _api.get('/v1/wallet'));

  @override
  Future<List<TopUpSource>> sources() async => _items(await _api.get('/v1/wallet/sources'))
      .map(
        (s) => TopUpSource(
          id: s['id'] as String,
          kind: TopUpKind.values.byName(s['kind'] as String),
          label: s['label'] as String,
          masked: s['masked'] as String,
        ),
      )
      .toList();

  @override
  Future<List<Beneficiary>> beneficiaries() async => _items(await _api.get('/v1/wallet/beneficiaries'))
      .map((b) => Beneficiary(id: b['id'] as String, name: b['name'] as String, phone: b['phone'] as String))
      .toList();

  @override
  Future<WalletOverview> topUp(int amount, String sourceId) async =>
      _overview(await _api.post('/v1/wallet/top-ups', body: {'amount': amount, 'source_id': sourceId}));

  @override
  Future<WalletOverview> transfer(String beneficiaryId, int amount, String? note) async => _overview(
        await _api.post('/v1/wallet/transfers', body: {'to': beneficiaryId, 'amount': amount, 'note': note}),
      );
}

/// Portefeuille simulé, avec un vrai solde en mémoire.
class WalletFakeDataSource implements WalletRemoteDataSource {
  WalletFakeDataSource(this._fake);
  final FakeBackend _fake;

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

  static const _beneficiaries = [
    Beneficiary(id: 'b1', name: '[Contact A]', phone: '+229 [00 00 00 00]'),
    Beneficiary(id: 'b2', name: '[Contact B]', phone: '+229 [00 00 00 00]'),
    Beneficiary(id: 'b3', name: '[Contact C]', phone: '+229 [00 00 00 00]'),
    Beneficiary(id: 'b4', name: '[Contact D]', phone: '+229 [00 00 00 00]'),
  ];

  WalletOverview _snapshot() => WalletOverview(
        wallet: Wallet(balance: _balance, points: 320, holder: '[Nom du titulaire]'),
        transactions: List.unmodifiable(_txs),
      );

  @override
  Future<WalletOverview> overview() async {
    await _fake.latency();
    return _snapshot();
  }

  @override
  Future<List<TopUpSource>> sources() async {
    await _fake.latency(0.4);
    return const [
      TopUpSource(id: 's1', kind: TopUpKind.mobileMoney, label: '[Opérateur A]', masked: '•• 12'),
      TopUpSource(id: 's2', kind: TopUpKind.mobileMoney, label: '[Opérateur B]', masked: '•• 47'),
      TopUpSource(id: 's3', kind: TopUpKind.card, label: 'Visa', masked: '•• 3021'),
    ];
  }

  @override
  Future<List<Beneficiary>> beneficiaries() async {
    await _fake.latency(0.4);
    return _beneficiaries;
  }

  @override
  Future<WalletOverview> topUp(int amount, String sourceId) async {
    await _fake.latency(2);
    _balance += amount;
    _txs.insert(
      0,
      WalletTransaction(
        id: 'n${_seq++}',
        label: 'Recharge',
        date: DateTime.now(),
        amount: amount,
        kind: TransactionKind.topUp,
      ),
    );
    return _snapshot();
  }

  @override
  Future<WalletOverview> transfer(String beneficiaryId, int amount, String? note) async {
    await _fake.latency(1.5);
    if (amount > _balance) throw const BusinessRuleException('insufficient_funds');
    final who = _beneficiaries.firstWhere((b) => b.id == beneficiaryId);
    _balance -= amount;
    _txs.insert(
      0,
      WalletTransaction(
        id: 'n${_seq++}',
        label: 'Transfert à ${who.name}',
        date: DateTime.now(),
        amount: -amount,
        kind: TransactionKind.transferOut,
      ),
    );
    return _snapshot();
  }
}

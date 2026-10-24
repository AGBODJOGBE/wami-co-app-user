import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wami/core/error/failures.dart';
import 'package:wami/core/utils/result.dart';
import 'package:wami/features/wallet/domain/entities/wallet.dart';
import 'package:wami/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:wami/features/wallet/domain/usecases/wallet_usecases.dart';

class _MockRepo extends Mock implements WalletRepository {}

void main() {
  late _MockRepo repo;
  late TransferMoney transfer;

  setUp(() {
    repo = _MockRepo();
    transfer = TransferMoney(repo);
  });

  test('refuse un transfert supérieur au solde, sans appeler le serveur', () async {
    final r = await transfer(const TransferParams(beneficiaryId: 'b1', amount: 5000, currentBalance: 2000));
    expect(r, isA<Err<WalletOverview>>());
    expect((r as Err<WalletOverview>).failure, isA<InsufficientFundsFailure>());
    verifyNever(() => repo.transfer(beneficiaryId: any(named: 'beneficiaryId'), amount: any(named: 'amount')));
  });

  test('transmet un transfert valide au repository', () async {
    const overview = WalletOverview(wallet: Wallet(balance: 1000, points: 0, holder: 'X'), transactions: []);
    when(() => repo.transfer(beneficiaryId: 'b1', amount: 1000, note: null))
        .thenAnswer((_) async => const Ok(overview));

    final r = await transfer(const TransferParams(beneficiaryId: 'b1', amount: 1000, currentBalance: 2000));
    expect(r.valueOrNull, overview);
  });
}

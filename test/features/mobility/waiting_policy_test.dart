import 'package:flutter_test/flutter_test.dart';
import 'package:wami/features/mobility/domain/entities/ride.dart';
import 'package:wami/features/mobility/domain/entities/waiting_policy.dart';

void main() {
  const policy = WaitingPolicy(freeWaitingSeconds: 120, waitingRatePerMinute: 50, pauseRatePerMinute: 25);

  group('Attente', () {
    test('gratuite pendant la période offerte', () {
      expect(policy.waitingFee(0), 0);
      expect(policy.waitingFee(120), 0);
      expect(policy.freeLeft(100), 20);
    });

    test('chaque minute entamée est facturée', () {
      expect(policy.waitingFee(121), 50);
      expect(policy.waitingFee(180), 50);
      expect(policy.waitingFee(181), 100);
    });
  });

  group('Pause', () {
    test('facturée à la minute entamée', () {
      expect(policy.pauseFee(8), 25);
      expect(policy.pauseFee(61), 50);
    });

    test('gratuite si la pause n’est pas facturée', () {
      const free = WaitingPolicy(pauseBilled: false);
      expect(free.pauseFee(300), 0);
    });
  });

  test('appel et message uniquement avant le démarrage de la course', () {
    expect(RideStatus.driverEnRoute.canContactDriver, isTrue);
    expect(RideStatus.driverArrived.canContactDriver, isTrue);
    expect(RideStatus.inProgress.canContactDriver, isFalse);
    expect(RideStatus.paused.canContactDriver, isFalse);
  });
}

import 'package:equatable/equatable.dart';

/// Règles de facturation de l'attente et de la pause.
///
/// Toutes les valeurs sont **à valider** par la direction : elles viennent du
/// serveur en production, celles-ci ne servent que de défaut.
class WaitingPolicy extends Equatable {
  const WaitingPolicy({
    this.freeWaitingSeconds = 120,
    this.waitingRatePerMinute = 50,
    this.pauseBilled = true,
    this.pauseRatePerMinute = 25,
  });

  /// Attente gratuite après l'arrivée du chauffeur.
  final int freeWaitingSeconds;

  /// Prix de chaque minute entamée au-delà de l'attente gratuite.
  final int waitingRatePerMinute;

  /// La pause du chauffeur pendant la course est-elle facturée ?
  final bool pauseBilled;
  final int pauseRatePerMinute;

  /// Secondes gratuites restantes.
  int freeLeft(int waitedSeconds) => (freeWaitingSeconds - waitedSeconds).clamp(0, freeWaitingSeconds);

  /// Frais d'attente : chaque minute entamée après la période gratuite.
  int waitingFee(int waitedSeconds) {
    final billable = waitedSeconds - freeWaitingSeconds;
    if (billable <= 0) return 0;
    return ((billable + 59) ~/ 60) * waitingRatePerMinute;
  }

  /// Frais de pause : chaque minute entamée, si la pause est facturée.
  int pauseFee(int pausedSeconds) {
    if (!pauseBilled || pausedSeconds <= 0) return 0;
    return ((pausedSeconds + 59) ~/ 60) * pauseRatePerMinute;
  }

  @override
  List<Object?> get props => [freeWaitingSeconds, waitingRatePerMinute, pauseBilled, pauseRatePerMinute];
}

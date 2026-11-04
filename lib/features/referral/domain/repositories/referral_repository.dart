import '../../../../core/utils/result.dart';
import '../entities/referral.dart';

abstract interface class ReferralRepository {
  Future<Result<ReferralOverview>> getOverview();

  /// Utilise le code d'un proche. Renvoie ce que l'utilisateur recevra une fois sa première course faite.
  Future<Result<IncomingReferral>> applyCode(String code);
}

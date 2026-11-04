import 'package:equatable/equatable.dart';

enum ReferralStatus {
  pending('En attente'),
  validated('Validé'),
  expired('Expiré');

  const ReferralStatus(this.label);
  final String label;

  static ReferralStatus fromApi(String? value) => switch (value) {
        'VALIDATED' => ReferralStatus.validated,
        'EXPIRED' || 'CANCELLED' || 'REJECTED' => ReferralStatus.expired,
        _ => ReferralStatus.pending,
      };
}

/// Un proche parrainé par l'utilisateur.
class Referral extends Equatable {
  const Referral({
    required this.id,
    required this.name,
    required this.status,
    required this.reward,
    required this.createdAt,
    this.validatedAt,
  });

  final String id;
  final String name;
  final ReferralStatus status;

  /// Gain du parrain une fois le parrainage validé (FCFA).
  final int reward;
  final DateTime createdAt;
  final DateTime? validatedAt;

  @override
  List<Object?> get props => [id, name, status, reward, createdAt, validatedAt];
}

/// Le parrainage dont l'utilisateur est lui-même le filleul, tant qu'il n'est pas validé.
class IncomingReferral extends Equatable {
  const IncomingReferral({required this.code, required this.reward});
  final String code;

  /// Ce que le filleul reçoit une fois sa première action faite (FCFA).
  final int reward;

  @override
  List<Object?> get props => [code, reward];
}

class ReferralOverview extends Equatable {
  const ReferralOverview({
    required this.code,
    required this.referrals,
    required this.pendingCount,
    required this.validatedCount,
    this.incoming,
  });

  /// Code de l'utilisateur, à partager.
  final String code;
  final List<Referral> referrals;
  final int pendingCount;
  final int validatedCount;
  final IncomingReferral? incoming;

  int get total => referrals.length;

  /// Gain par filleul validé, déduit des parrainages existants (le back ne publie pas son barème).
  int? get rewardPerReferral => referrals.isEmpty ? null : referrals.first.reward;

  @override
  List<Object?> get props => [code, referrals, pendingCount, validatedCount, incoming];
}

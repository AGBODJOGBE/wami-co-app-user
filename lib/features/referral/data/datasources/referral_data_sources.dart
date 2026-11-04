import '../../../../core/auth/current_session.dart';
import '../../../../core/data/fake_backend.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/referral.dart';

abstract interface class ReferralRemoteDataSource {
  Future<ReferralOverview> overview();
  Future<IncomingReferral> apply(String code);
}

/// Routes `/api/passenger/referrals/*` et profil du back wami-co.
///
/// La récompense est créditée par le back quand le filleul termine sa première action (course) : le mobile n'appelle
/// pas `POST /referrals/validate`.
class ReferralApiDataSource implements ReferralRemoteDataSource {
  const ReferralApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<ReferralOverview> overview() async {
    final results = await Future.wait([
      _api.get('/api/passengers/profile'),
      _api.get('/api/passenger/referrals/my'),
      _api.get('/api/passenger/referrals/my-pending'),
    ]);
    final profile = results[0];
    final mine = results[1];
    final pending = results[2];
    final referrals =
        (mine['referrals'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>().map(_referral).toList();
    return ReferralOverview(
      code: profile['referralCode'] as String? ?? '',
      referrals: referrals,
      pendingCount: (mine['totalPending'] as num?)?.toInt() ?? 0,
      validatedCount: (mine['totalValidated'] as num?)?.toInt() ?? 0,
      // `my-pending` répond `data: null` quand l'utilisateur n'a pas de parrainage en cours.
      incoming: pending['referralCode'] == null ? null : _incoming(pending),
    );
  }

  @override
  Future<IncomingReferral> apply(String code) async {
    try {
      final json = await _api.post('/api/passenger/referrals/apply', body: {'referralCode': code});
      return IncomingReferral(code: code, reward: (json['referredReward'] as num?)?.toInt() ?? 0);
    } on BusinessRuleException catch (e) {
      throw _frenchApplyError(e);
    }
  }

  /// Le back répond en anglais : on traduit les refus que l'utilisateur peut rencontrer.
  BusinessRuleException _frenchApplyError(BusinessRuleException e) {
    final m = (e.message ?? '').toLowerCase();
    if (m.contains('does not exist') || m.contains('not found')) {
      return const BusinessRuleException('rejected', 'Code de parrainage inconnu.');
    }
    if (m.contains('yourself')) {
      return const BusinessRuleException('rejected', 'Vous ne pouvez pas utiliser votre propre code.');
    }
    if (m.contains('already been referred')) {
      return const BusinessRuleException('rejected', 'Vous avez déjà utilisé un code de parrainage.');
    }
    return e;
  }

  Referral _referral(Map<String, dynamic> j) => Referral(
        id: j['referralId'] as String,
        name: (j['referredName'] as String?)?.trim().isNotEmpty ?? false ? j['referredName'] as String : 'Un proche',
        status: ReferralStatus.fromApi(j['status'] as String?),
        reward: (j['referrerReward'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
        validatedAt: DateTime.tryParse(j['validatedAt'] as String? ?? '')?.toLocal(),
      );

  IncomingReferral _incoming(Map<String, dynamic> j) =>
      IncomingReferral(code: j['referralCode'] as String, reward: (j['referredReward'] as num?)?.toInt() ?? 0);
}

/// Parrainage simulé : le code d'un proche valable est `AMI123`.
class ReferralFakeDataSource implements ReferralRemoteDataSource {
  ReferralFakeDataSource(this._fake, this._session);
  final FakeBackend _fake;
  final CurrentSession _session;

  IncomingReferral? _incoming;

  @override
  Future<ReferralOverview> overview() async {
    await _fake.latency();
    return ReferralOverview(
      code:
          'WAMI${(_session.value?.firstName ?? 'AMI').toUpperCase().replaceAll(' ', '').padRight(3, 'X').substring(0, 3)}1',
      referrals: [
        Referral(
          id: 'r1',
          name: 'Koffi Adjovi',
          status: ReferralStatus.validated,
          reward: 500,
          createdAt: DateTime.now().subtract(const Duration(days: 12)),
          validatedAt: DateTime.now().subtract(const Duration(days: 9)),
        ),
        Referral(
          id: 'r2',
          name: 'Awa Dossou',
          status: ReferralStatus.pending,
          reward: 500,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ],
      pendingCount: 1,
      validatedCount: 1,
      incoming: _incoming,
    );
  }

  @override
  Future<IncomingReferral> apply(String code) async {
    await _fake.latency();
    if (_incoming != null) {
      throw const BusinessRuleException('rejected', 'Vous avez déjà utilisé un code de parrainage.');
    }
    if (code != 'AMI123') throw const BusinessRuleException('rejected', 'Code de parrainage inconnu.');
    return _incoming = const IncomingReferral(code: 'AMI123', reward: 300);
  }
}

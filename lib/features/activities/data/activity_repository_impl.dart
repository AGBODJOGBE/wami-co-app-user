import '../../../core/data/fake_backend.dart';
import '../../../core/data/repository_guard.dart';
import '../../../core/domain/service_type.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/result.dart';
import '../domain/activity.dart';

abstract interface class ActivityRemoteDataSource {
  Future<List<Activity>> fetch();
}

/// Livraisons du passager (`GET /api/passenger/delivery`).
///
/// Les courses n'apparaissent pas encore : le back n'expose pas l'historique des courses du passager
/// (`GetRideHistoryController` existe mais n'est branché sur aucune route, voir docs/BACKEND_A_FAIRE.md).
/// Bus et hébergement n'existent pas côté back.
class ActivityApiDataSource implements ActivityRemoteDataSource {
  const ActivityApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<List<Activity>> fetch() async {
    final json = await _api.get('/api/passenger/delivery');
    final items = (json['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    return items.map(delivery).toList();
  }

  static Activity delivery(Map<String, dynamic> j) {
    final dropoff = (j['dropoff'] as Map<String, dynamic>?)?['address'] as String? ?? '';
    final driver = (j['driver'] as Map<String, dynamic>?)?['name'] as String?;
    final status = _status(j['status'] as String?, j['scheduledAt'] as String?);
    return Activity(
      id: j['id'] as String,
      service: ServiceType.delivery,
      title: dropoff.isEmpty ? 'Colis' : 'Colis vers $dropoff',
      subtitle: switch (status) {
        ActivityStatus.ongoing => driver == null ? 'Recherche d’un coursier' : 'Coursier : $driver',
        ActivityStatus.upcoming => 'Livraison programmée',
        ActivityStatus.done => 'Livré',
        ActivityStatus.cancelled => 'Annulé',
      },
      date: DateTime.parse(j['createdAt'] as String).toLocal(),
      amount: ((j['finalPrice'] ?? j['estimatedPrice']) as num?)?.toInt() ?? 0,
      status: status,
    );
  }

  static ActivityStatus _status(String? status, String? scheduledAt) {
    switch (status) {
      case 'COMPLETED' || 'RETURNED':
        return ActivityStatus.done;
      case 'CANCELLED' || 'PICKUP_FAILED' || 'DELIVERY_FAILED':
        return ActivityStatus.cancelled;
      case 'PENDING_MATCH':
        final at = DateTime.tryParse(scheduledAt ?? '');
        return at != null && at.isAfter(DateTime.now()) ? ActivityStatus.upcoming : ActivityStatus.ongoing;
      default:
        return ActivityStatus.ongoing;
    }
  }
}

class ActivityFakeDataSource implements ActivityRemoteDataSource {
  const ActivityFakeDataSource(this._fake);
  final FakeBackend _fake;

  @override
  Future<List<Activity>> fetch() async {
    await _fake.latency();
    final now = DateTime.now();
    return [
      Activity(
        id: 'a1',
        service: ServiceType.delivery,
        title: 'Colis vers [Quartier]',
        subtitle: 'Coursier en route',
        date: now,
        amount: 1500,
        status: ActivityStatus.ongoing,
      ),
      Activity(
        id: 'a2',
        service: ServiceType.bus,
        title: 'Cotonou → Parakou',
        subtitle: '[Compagnie C] · siège 4C',
        date: now.add(const Duration(days: 2)),
        amount: 9500,
        status: ActivityStatus.upcoming,
      ),
      Activity(
        id: 'a3',
        service: ServiceType.mobility,
        title: 'Course Confort',
        subtitle: 'Dantokpa → Fidjrossè',
        date: now.subtract(const Duration(hours: 3)),
        amount: 2800,
        status: ActivityStatus.done,
      ),
      Activity(
        id: 'a4',
        service: ServiceType.lodging,
        title: '[Hôtel A]',
        subtitle: '2 nuits · Parakou',
        date: now.subtract(const Duration(days: 9)),
        amount: 50000,
        status: ActivityStatus.done,
      ),
      Activity(
        id: 'a5',
        service: ServiceType.mobility,
        title: 'Course Moto',
        subtitle: 'Annulée par vous',
        date: now.subtract(const Duration(days: 12)),
        amount: 0,
        status: ActivityStatus.cancelled,
      ),
    ];
  }
}

class ActivityRepositoryImpl implements ActivityRepository {
  const ActivityRepositoryImpl(this._remote);
  final ActivityRemoteDataSource _remote;

  @override
  Future<Result<List<Activity>>> getActivities() => guard(_remote.fetch);
}

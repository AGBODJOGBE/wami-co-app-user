import '../../../core/data/fake_backend.dart';
import '../../../core/data/repository_guard.dart';
import '../../../core/domain/service_type.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/result.dart';
import '../domain/activity.dart';

abstract interface class ActivityRemoteDataSource {
  Future<List<Activity>> fetch();
}

/// Endpoint à valider.
class ActivityApiDataSource implements ActivityRemoteDataSource {
  const ActivityApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<List<Activity>> fetch() async {
    final json = await _api.get('/v1/activities');
    return (json['items'] as List<dynamic>).cast<Map<String, dynamic>>().map((j) {
      return Activity(
        id: j['id'] as String,
        service: ServiceType.values.byName(j['service'] as String),
        title: j['title'] as String,
        subtitle: j['subtitle'] as String? ?? '',
        date: DateTime.parse(j['date'] as String),
        amount: j['amount'] as int,
        status: ActivityStatus.values.byName(j['status'] as String),
      );
    }).toList();
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

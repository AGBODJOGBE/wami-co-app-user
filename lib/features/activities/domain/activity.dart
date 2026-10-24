import 'package:equatable/equatable.dart';

import '../../../core/domain/service_type.dart';
import '../../../core/usecase/usecase.dart';
import '../../../core/utils/result.dart';

enum ActivityStatus {
  ongoing('En cours'),
  upcoming('À venir'),
  done('Terminé'),
  cancelled('Annulé');

  const ActivityStatus(this.label);
  final String label;
}

/// Historique transverse à tous les services.
class Activity extends Equatable {
  const Activity({
    required this.id,
    required this.service,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.amount,
    required this.status,
  });

  final String id;
  final ServiceType service;
  final String title;
  final String subtitle;
  final DateTime date;
  final int amount;
  final ActivityStatus status;

  @override
  List<Object?> get props => [id, service, title, subtitle, date, amount, status];
}

abstract interface class ActivityRepository {
  Future<Result<List<Activity>>> getActivities();
}

/// Activités triées : en cours, puis à venir, puis les plus récentes.
class GetActivities implements UseCase<List<Activity>, NoParams> {
  const GetActivities(this._repo);
  final ActivityRepository _repo;

  @override
  Future<Result<List<Activity>>> call(NoParams _) async {
    final r = await _repo.getActivities();
    return r.map(
      (list) => [...list]..sort((a, b) {
          final byStatus = a.status.index.compareTo(b.status.index);
          return byStatus != 0 ? byStatus : b.date.compareTo(a.date);
        }),
    );
  }
}

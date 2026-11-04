import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/load_status.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/usecases/notifications_usecases.dart';

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = LoadStatus.idle,
    this.items = const [],
    this.page = 0,
    this.totalPages = 1,
    this.loadingMore = false,
    this.failure,
  });

  final LoadStatus status;
  final List<AppNotification> items;
  final int page;
  final int totalPages;
  final bool loadingMore;
  final Failure? failure;

  bool get hasMore => page < totalPages;

  /// Non lues parmi celles déjà chargées (le back ne donne pas de compteur global).
  int get unreadCount => items.where((n) => !n.isRead).length;

  NotificationsState copyWith({
    LoadStatus? status,
    List<AppNotification>? items,
    int? page,
    int? totalPages,
    bool? loadingMore,
    Failure? failure,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      items: items ?? this.items,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      loadingMore: loadingMore ?? this.loadingMore,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, items, page, totalPages, loadingMore, failure];
}

/// Notifications du passager. Global : la cloche de l'accueil affiche le nombre de non lues.
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(this._get, this._markRead) : super(const NotificationsState());
  final GetNotifications _get;
  final MarkNotificationRead _markRead;

  /// Déconnexion : les notifications de l'utilisateur précédent ne doivent pas survivre.
  void reset() => emit(const NotificationsState());

  Future<void> load() async {
    // Garde la liste actuelle affichée pendant l'actualisation.
    emit(state.copyWith(status: state.items.isEmpty ? LoadStatus.loading : state.status));
    final r = await _get(1);
    emit(
      r.fold(
        (f) => state.copyWith(status: state.items.isEmpty ? LoadStatus.failure : state.status, failure: f),
        (p) => state.copyWith(status: LoadStatus.ready, items: p.items, page: p.page, totalPages: p.totalPages),
      ),
    );
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    emit(state.copyWith(loadingMore: true));
    final r = await _get(state.page + 1);
    emit(
      r.fold(
        (f) => state.copyWith(loadingMore: false, failure: f),
        (p) => state.copyWith(
          loadingMore: false,
          items: [
            ...state.items,
            // Une notification peut changer de page entre deux appels : pas de doublon.
            for (final n in p.items)
              if (!state.items.any((k) => k.id == n.id)) n,
          ],
          page: p.page,
          totalPages: p.totalPages,
        ),
      ),
    );
  }

  /// Marque lue tout de suite à l'écran, puis prévient le back. Un échec réseau n'annule pas l'affichage :
  /// la notification reste lue ici et le serveur la rendra de nouveau non lue au prochain chargement.
  Future<void> markRead(String id) async {
    final i = state.items.indexWhere((n) => n.id == id);
    if (i == -1 || state.items[i].isRead) return;
    final items = [...state.items]..[i] = state.items[i].markedRead();
    emit(state.copyWith(items: items));
    await _markRead(id);
  }
}

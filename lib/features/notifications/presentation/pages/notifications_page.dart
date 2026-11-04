import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/wami_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/load_status.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../domain/entities/app_notification.dart';
import '../cubit/notifications_cubit.dart';

/// Notifications : les plus récentes en haut, regroupées par jour.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    // Actualise à l'ouverture : de nouvelles notifications ont pu arriver depuis le chargement de la connexion.
    context.read<NotificationsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        return WamiScreen(
          title: 'Notifications',
          subtitle: state.unreadCount > 0 ? '${state.unreadCount} non lue${state.unreadCount > 1 ? 's' : ''}' : null,
          body: _body(context, state),
        );
      },
    );
  }

  Widget _body(BuildContext context, NotificationsState state) {
    if (state.status == LoadStatus.loading && state.items.isEmpty) {
      return const SizedBox(height: 260, child: WamiLoading());
    }
    if (state.status == LoadStatus.failure && state.items.isEmpty) {
      return WamiErrorView(failure: state.failure!, onRetry: () => context.read<NotificationsCubit>().load());
    }
    if (state.items.isEmpty) {
      return SizedBox(
        height: 260,
        child: Center(
          child: Text('Aucune notification pour le moment.', style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }
    final groups = <String, List<AppNotification>>{};
    for (final n in state.items) {
      groups.putIfAbsent(Fmt.relativeDay(n.createdAt), () => []).add(n);
    }
    return Gap(
      children: [
        for (final entry in groups.entries) ...[
          SectionLabel(entry.key),
          GlassGroup(children: [for (final n in entry.value) _NotificationTile(notification: n)]),
        ],
        if (state.hasMore)
          WamiGhostButton(
            label: state.loadingMore ? 'Chargement…' : 'Voir plus',
            onPressed: state.loadingMore ? null : () => context.read<NotificationsCubit>().loadMore(),
          ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});
  final AppNotification notification;

  IconData get _icon => switch (notification.category) {
        NotificationCategory.ride => Icons.directions_car_rounded,
        NotificationCategory.delivery => Icons.inventory_2_rounded,
        NotificationCategory.wallet => Icons.account_balance_wallet_rounded,
        NotificationCategory.other => Icons.notifications_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final unread = !notification.isRead;
    return Semantics(
      label: '${unread ? 'Non lue. ' : ''}${notification.title}. ${notification.message}',
      child: ListTile(
        onTap: () => context.read<NotificationsCubit>().markRead(notification.id),
        leading: IconBadge(_icon),
        title: Text(notification.title, style: t.titleSmall?.copyWith(fontWeight: unread ? FontWeight.w800 : null)),
        subtitle: Text(notification.message, style: t.bodySmall),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(Fmt.hhmm(notification.createdAt), style: t.bodySmall?.copyWith(fontSize: 11)),
            if (unread)
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: WamiColors.orange, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

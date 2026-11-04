import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/wami_colors.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../cubit/notifications_cubit.dart';

/// Cloche de l'accueil : ouvre les notifications, avec une pastille quand il y en a de non lues.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      buildWhen: (a, b) => a.unreadCount != b.unreadCount,
      builder: (context, state) {
        final unread = state.unreadCount;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            WamiIconButton(
              icon: unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
              tooltip: unread > 0 ? 'Notifications, $unread non lues' : 'Notifications',
              onPressed: () => context.push(Routes.notifications),
            ),
            if (unread > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: WamiColors.orange,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

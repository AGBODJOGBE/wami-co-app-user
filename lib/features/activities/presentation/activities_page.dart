import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/domain/service_type.dart';
import '../../../core/error/failures.dart';
import '../../../core/theme/wami_palette.dart';
import '../../../core/theme/wami_tokens.dart';
import '../../../core/usecase/usecase.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/load_status.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/wami_background.dart';
import '../../../core/widgets/wami_basics.dart';
import '../../../core/widgets/wami_scaffold.dart';
import '../../../core/widgets/wami_selectors.dart';
import '../domain/activity.dart';

class ActivitiesState extends Equatable {
  const ActivitiesState({this.status = LoadStatus.idle, this.items = const [], this.filter, this.failure});
  final LoadStatus status;
  final List<Activity> items;

  /// `null` = tous les services.
  final ServiceType? filter;
  final Failure? failure;

  List<Activity> get visible => filter == null ? items : items.where((a) => a.service == filter).toList();

  @override
  List<Object?> get props => [status, items, filter, failure];
}

class ActivitiesCubit extends Cubit<ActivitiesState> {
  ActivitiesCubit(this._get) : super(const ActivitiesState());
  final GetActivities _get;

  Future<void> load() async {
    emit(ActivitiesState(status: LoadStatus.loading, filter: state.filter));
    final r = await _get(const NoParams());
    emit(
      r.fold(
        (f) => ActivitiesState(status: LoadStatus.failure, failure: f, filter: state.filter),
        (items) => ActivitiesState(status: LoadStatus.ready, items: items, filter: state.filter),
      ),
    );
  }

  void setFilter(ServiceType? s) => emit(ActivitiesState(status: state.status, items: state.items, filter: s));
}

class ActivitiesPage extends StatelessWidget {
  const ActivitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ActivitiesCubit>()..load(),
      child: WamiBackground(
        child: SafeArea(
          bottom: false,
          child: BlocBuilder<ActivitiesCubit, ActivitiesState>(
            builder: (context, state) {
              final cubit = context.read<ActivitiesCubit>();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(WamiSpace.screen, 12, WamiSpace.screen, 12),
                    child: Text('Activités', style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  ChipRow(
                    children: [
                      WamiChip(label: 'Tout', selected: state.filter == null, onTap: () => cubit.setFilter(null)),
                      for (final s in ServiceType.values)
                        WamiChip(label: s.label, selected: state.filter == s, onTap: () => cubit.setFilter(s)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: switch (state.status) {
                      LoadStatus.idle || LoadStatus.loading => const WamiLoading(),
                      LoadStatus.failure => WamiErrorView(failure: state.failure!, onRetry: cubit.load),
                      LoadStatus.ready => RefreshIndicator(
                          onRefresh: cubit.load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(WamiSpace.screen, 0, WamiSpace.screen, 110),
                            itemCount: state.visible.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _ActivityTile(activity: state.visible[i]),
                          ),
                        ),
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = activity;
    final live = a.status == ActivityStatus.ongoing;
    return GlassCard(
      borderColor: live ? a.service.glow.withValues(alpha: 0.6) : null,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: a.service.glow.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ServiceIllustration(a.service.art, size: 46),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, style: t.titleSmall),
                Text(
                  '${a.subtitle} · ${Fmt.relativeDay(a.date)}',
                  style: t.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (a.amount > 0) NumberText(Fmt.fcfa(a.amount), size: 13),
              const SizedBox(height: 4),
              WamiTag(a.status.label, tint: live ? a.service.glow : context.wami.inkMuted),
            ],
          ),
        ],
      ),
    );
  }
}

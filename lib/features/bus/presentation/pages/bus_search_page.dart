import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/service_type.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/wami_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../../../core/widgets/wami_buttons.dart';
import '../../../../core/widgets/wami_scaffold.dart';
import '../../../../core/widgets/wami_selectors.dart';
import '../cubit/bus_booking_cubit.dart';

class BusSearchPage extends StatelessWidget {
  const BusSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BusBookingCubit>();
    final t = Theme.of(context).textTheme;
    final today = DateTime.now();
    final days = [for (var i = 0; i < 6; i++) DateTime(today.year, today.month, today.day + i)];

    return BlocBuilder<BusBookingCubit, BusBookingState>(
      builder: (context, state) {
        final q = state.query;
        return WamiScreen(
          title: 'Billets de bus',
          glow: ServiceType.bus.glow,
          onBack: () => context.go(Routes.home),
          body: Gap(
            children: [
              Row(
                children: [
                  Expanded(child: Text('Comparez les compagnies et réservez votre siège.', style: t.bodySmall)),
                  const ServiceIllustration(ServiceArt.bus, size: 96),
                ],
              ),
              GlassCard(
                padding: const EdgeInsets.all(12),
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    Column(
                      children: [
                        _CityField(label: 'Départ', city: q.from, color: WamiColors.white),
                        const SizedBox(height: 8),
                        _CityField(label: 'Arrivée', city: q.to, color: WamiColors.glowBus),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: WamiIconButton(
                        icon: Icons.swap_vert_rounded,
                        tooltip: 'Inverser départ et arrivée',
                        color: WamiColors.glowBus,
                        onPressed: cubit.swapCities,
                      ),
                    ),
                  ],
                ),
              ),
              const SectionLabel('Date'),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: days.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => WamiChip(
                    label: Fmt.relativeDay(days[i]),
                    selected: DateUtils.isSameDay(days[i], q.date),
                    onTap: () => cubit.setDate(days[i]),
                  ),
                ),
              ),
              GlassCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Voyageurs', style: t.titleSmall),
                          Text('Un siège par voyageur', style: t.bodySmall),
                        ],
                      ),
                    ),
                    CounterStepper(value: q.passengers, max: 4, label: 'voyageur', onChanged: cubit.setPassengers),
                  ],
                ),
              ),
            ],
          ),
          bottom: WamiPrimaryButton(
            label: 'Rechercher',
            onPressed: () {
              cubit.search();
              context.push(Routes.busResults);
            },
          ),
        );
      },
    );
  }
}

class _CityField extends StatelessWidget {
  const _CityField({required this.label, required this.city, required this.color});
  final String label;
  final String city;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(Icons.place_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: t.bodySmall?.copyWith(fontSize: 10.5)),
              Text(city, style: t.titleSmall),
            ],
          ),
        ],
      ),
    );
  }
}

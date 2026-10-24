import 'package:flutter/material.dart';

import '../../../../core/domain/service_type.dart';
import '../../../../core/theme/wami_palette.dart';
import '../../../../core/theme/wami_tokens.dart';
import '../../../../core/widgets/wami_basics.dart';

/// Grille des services de base : illustration 3D + lueur de l'univers.
class ServiceGrid extends StatelessWidget {
  const ServiceGrid({super.key, required this.onOpen});
  final ValueChanged<ServiceType> onOpen;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: WamiSpace.s3,
      crossAxisSpacing: WamiSpace.s3,
      childAspectRatio: 1.15,
      children: [
        for (final s in ServiceType.values) _ServiceTile(service: s, onTap: () => onOpen(s)),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.onTap});
  final ServiceType service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.wami;
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${service.label}, ${service.tagline}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(WamiRadius.lg),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(WamiRadius.lg),
              border: Border.all(color: p.glassBorder),
              gradient: RadialGradient(
                center: const Alignment(0.6, -0.8),
                radius: 1.1,
                colors: [service.glow.withValues(alpha: 0.30), p.glass],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: ServiceIllustration(service.art, size: 72),
                    ),
                  ),
                  Text(service.label, style: t.titleMedium),
                  Text(
                    service.tagline,
                    style: t.bodySmall?.copyWith(fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

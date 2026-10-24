import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/wami_colors.dart';
import '../../../../core/theme/wami_palette.dart';
import '../../../../core/theme/wami_tokens.dart';
import '../../../../core/widgets/wami_basics.dart';
import '../../domain/entities/home_feed.dart';

/// Carrousel publicitaire : défilement automatique toutes les 5 s,
/// pause dès que l'utilisateur le touche, indicateurs en pastilles.
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key, required this.promos, required this.onOpen});

  final List<PromoBanner> promos;
  final ValueChanged<PromoBanner> onOpen;

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    if (widget.promos.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients) return;
      final next = (_index + 1) % widget.promos.length;
      _controller.animateToPage(next, duration: WamiMotion.slow, curve: WamiMotion.curve);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.promos.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Listener(
            onPointerDown: (_) => _timer?.cancel(),
            onPointerUp: (_) => _start(),
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.promos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _PromoCard(promo: widget.promos[i], onTap: () => widget.onOpen(widget.promos[i])),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.promos.length; i++)
              AnimatedContainer(
                duration: WamiMotion.base,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _index ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: i == _index ? WamiEffects.ctaGradient : null,
                  color: i == _index ? null : context.wami.ink.withValues(alpha: 0.25),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.promo, required this.onTap});
  final PromoBanner promo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glow = promo.service.glow;
    return Semantics(
      button: true,
      label: '${promo.title}. ${promo.ctaLabel}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WamiRadius.xl),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E2F57), Color(0xFF0E1830)],
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(1, -0.6),
                      radius: 1.1,
                      colors: [glow.withValues(alpha: 0.55), glow.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -6,
                bottom: -8,
                child: ServiceIllustration(promo.service.art, size: 120),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 120, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promo.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Unbounded',
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: WamiColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      promo.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFC9D0DF)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: WamiEffects.ctaGradient,
                        borderRadius: BorderRadius.circular(WamiRadius.pill),
                      ),
                      child: Text(
                        promo.ctaLabel,
                        style: const TextStyle(color: WamiColors.white, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

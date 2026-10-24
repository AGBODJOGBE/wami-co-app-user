import 'package:equatable/equatable.dart';

import '../../../../core/domain/service_type.dart';

/// Bannière publicitaire du carrousel d'accueil.
class PromoBanner extends Equatable {
  const PromoBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.service,
  });

  final String id;
  final String title;
  final String subtitle;
  final String ctaLabel;

  /// Service ouvert au clic sur la bannière.
  final ServiceType service;

  @override
  List<Object?> get props => [id, title, subtitle, ctaLabel, service];
}

/// Raccourci intelligent (« Maison », « Travail », dernière destination…).
class QuickDestination extends Equatable {
  const QuickDestination({required this.id, required this.label, required this.address, required this.kind});

  final String id;
  final String label;
  final String address;
  final QuickDestinationKind kind;

  @override
  List<Object?> get props => [id, label, address, kind];
}

enum QuickDestinationKind { home, work, recent }

/// Contenu de l'écran d'accueil.
class HomeFeed extends Equatable {
  const HomeFeed({required this.firstName, required this.promos, required this.quickDestinations});

  final String firstName;
  final List<PromoBanner> promos;
  final List<QuickDestination> quickDestinations;

  @override
  List<Object?> get props => [firstName, promos, quickDestinations];
}

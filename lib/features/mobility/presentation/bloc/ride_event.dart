part of 'ride_bloc.dart';

sealed class RideEvent extends Equatable {
  const RideEvent();

  @override
  List<Object?> get props => [];
}

final class RideStarted extends RideEvent {
  const RideStarted({this.initialQuery});
  final String? initialQuery;

  @override
  List<Object?> get props => [initialQuery];
}

final class RideQueryChanged extends RideEvent {
  const RideQueryChanged(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

final class RideDestinationChosen extends RideEvent {
  const RideDestinationChosen(this.place);
  final Place place;

  @override
  List<Object?> get props => [place];
}

final class RideCategorySelected extends RideEvent {
  const RideCategorySelected(this.category);
  final VehicleCategory category;

  @override
  List<Object?> get props => [category];
}

final class RideBooked extends RideEvent {
  const RideBooked();
}

final class RideCancelled extends RideEvent {
  const RideCancelled();
}

final class RideRated extends RideEvent {
  const RideRated({required this.stars, required this.tags, this.tip = 0});
  final int stars;
  final Set<String> tags;
  final int tip;

  @override
  List<Object?> get props => [stars, tags, tip];
}

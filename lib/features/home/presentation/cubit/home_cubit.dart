import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/home_feed.dart';
import '../../domain/usecases/get_home_feed.dart';

enum HomeStatus { loading, ready, failure }

class HomeState extends Equatable {
  const HomeState({this.status = HomeStatus.loading, this.feed, this.failure});

  final HomeStatus status;
  final HomeFeed? feed;
  final Failure? failure;

  @override
  List<Object?> get props => [status, feed, failure];
}

class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._getFeed) : super(const HomeState());
  final GetHomeFeed _getFeed;

  Future<void> load() async {
    emit(const HomeState());
    final result = await _getFeed(const NoParams());
    emit(
      result.fold(
        (f) => HomeState(status: HomeStatus.failure, failure: f),
        (feed) => HomeState(status: HomeStatus.ready, feed: feed),
      ),
    );
  }
}

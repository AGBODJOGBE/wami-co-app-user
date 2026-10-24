import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/usecases/account_usecases.dart';

class SupportState extends Equatable {
  const SupportState({this.faq = const [], this.openIndex = 0, this.query = '', this.exportSent = false});
  final List<FaqItem> faq;
  final int openIndex;
  final String query;
  final bool exportSent;

  List<FaqItem> get filtered {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return faq;
    return faq.where((f) => f.question.toLowerCase().contains(q) || f.answer.toLowerCase().contains(q)).toList();
  }

  SupportState copyWith({List<FaqItem>? faq, int? openIndex, String? query, bool? exportSent}) => SupportState(
        faq: faq ?? this.faq,
        openIndex: openIndex ?? this.openIndex,
        query: query ?? this.query,
        exportSent: exportSent ?? this.exportSent,
      );

  @override
  List<Object?> get props => [faq, openIndex, query, exportSent];
}

/// Assistance (FAQ) et demandes liées aux données personnelles.
class SupportCubit extends Cubit<SupportState> {
  SupportCubit(this._getFaq, this._export) : super(const SupportState());
  final GetFaq _getFaq;
  final RequestDataExport _export;

  Future<void> load() async {
    final r = await _getFaq(const NoParams());
    emit(state.copyWith(faq: r.valueOrNull ?? const []));
  }

  void toggle(int i) => emit(state.copyWith(openIndex: state.openIndex == i ? -1 : i));
  void search(String q) => emit(state.copyWith(query: q, openIndex: 0));

  Future<void> exportData() async {
    final r = await _export(const NoParams());
    emit(state.copyWith(exportSent: r.isOk));
  }
}

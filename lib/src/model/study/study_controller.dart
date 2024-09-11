import 'package:dartchess/dartchess.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/model/common/http.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/study/study.dart';
import 'package:lichess_mobile/src/model/study/study_analysis.dart';
import 'package:lichess_mobile/src/model/study/study_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'study_controller.freezed.dart';
part 'study_controller.g.dart';

@riverpod
class StudyController extends _$StudyController {
  @override
  Future<StudyState> build(StudyId id) async {
    final (study, analysis) = await ref.withClient(
      (client) => StudyRepository(client).getStudy(id: id),
    );
    return StudyState(
      study: study,
      analysis: analysis,
    );
  }

  Future<void> loadChapter(StudyChapterId chapterId) async {
    if (!state.hasValue) return;

    final id = state.requireValue.study.id;

    final (study, analysis) = await ref.withClient(
      (client) =>
          StudyRepository(client).getStudy(id: id, chapterId: chapterId),
    );

    state = AsyncValue.data(
      state.requireValue.copyWith(
        study: study,
        analysis: analysis,
      ),
    );
  }
}

@freezed
class StudyState with _$StudyState {
  const factory StudyState({
    required Study study,
    required StudyAnalysis analysis,
  }) = _StudyState;

  const StudyState._();

  StudyChapter get currentChapter => study.chapter;

  // TODO get from "analyis" field of the API response
  String get initialFen =>
      study.chapters
          .firstWhere(
            (chapter) => chapter.id == currentChapter.id,
          )
          .fen ??
      kInitialFEN;
}

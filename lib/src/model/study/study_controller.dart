import 'package:dartchess/dartchess.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/model/common/http.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/study/study.dart';
import 'package:lichess_mobile/src/model/study/study_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'study_controller.freezed.dart';
part 'study_controller.g.dart';

@riverpod
class StudyController extends _$StudyController {
  @override
  Future<StudyState> build(StudyId id) async => StudyState(
        study: await ref
            .withClient((client) => StudyRepository(client).getStudy(id: id)),
      );

  Future<void> loadChapter(StudyChapterId chapterId) async {
    if (!state.hasValue) return;

    final id = state.requireValue.study.id;

    state = AsyncValue.data(
      state.requireValue.copyWith(
        study: await ref.withClient(
          (client) =>
              StudyRepository(client).getStudy(id: id, chapterId: chapterId),
        ),
      ),
    );
  }
}

@freezed
class StudyState with _$StudyState {
  const factory StudyState({
    required Study study,
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

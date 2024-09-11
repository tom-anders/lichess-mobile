import 'package:dartchess/dartchess.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/model/common/http.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/study/study.dart';
import 'package:lichess_mobile/src/model/study/study_analysis.dart';
import 'package:lichess_mobile/src/model/study/study_node.dart';
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
    return StudyState.fromServerResponse(
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
      StudyState.fromServerResponse(
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
    // TODO we probably don't even need to store this anymore.
    // Should be enough to store orientation (and maybe initialFen and Variant?)
    required StudyAnalysis analysis,
    required StudyRoot tree,
    required StudyNode currentNode,
  }) = _StudyState;

  factory StudyState.fromServerResponse({
    required Study study,
    required StudyAnalysis analysis,
  }) {
    final tree = StudyRoot.fromServerTreeParts(
      analysis.treeParts,
      study.chapter.setup.variant,
    );
    return StudyState(
      study: study,
      analysis: analysis,
      tree: tree,
      currentNode: tree,
    );
  }

  const StudyState._();

  StudyChapter get currentChapter => study.chapter;

  bool get canGoBack => currentNode is! StudyRoot;

  bool get canGoForward => currentNode.children.isNotEmpty;

  // TODO get from "analyis" field of the API response
  String get initialFen =>
      study.chapters
          .firstWhere(
            (chapter) => chapter.id == currentChapter.id,
          )
          .fen ??
      kInitialFEN;
}

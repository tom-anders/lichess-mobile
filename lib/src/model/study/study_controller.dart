import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_controller.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_preferences.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/http.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/common/node.dart';
import 'package:lichess_mobile/src/model/common/service/move_feedback.dart';
import 'package:lichess_mobile/src/model/common/service/sound_service.dart';
import 'package:lichess_mobile/src/model/common/uci.dart';
import 'package:lichess_mobile/src/model/engine/evaluation_service.dart';
import 'package:lichess_mobile/src/model/engine/work.dart';
import 'package:lichess_mobile/src/model/study/study.dart';
import 'package:lichess_mobile/src/model/study/study_repository.dart';
import 'package:lichess_mobile/src/utils/rate_limit.dart';
import 'package:lichess_mobile/src/widgets/pgn_tree_view.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'study_controller.freezed.dart';
part 'study_controller.g.dart';

@riverpod
class StudyController extends _$StudyController implements PgnTreeViewNotifier {
  late Root _root;

  final _engineEvalDebounce = Debouncer(const Duration(milliseconds: 150));

  Timer? _startEngineEvalTimer;

  Future<void> nextChapter() async {
    if (state.hasValue) {
      final chapters = state.requireValue.study.chapters;
      final currentChapterIndex = chapters.indexWhere(
        (chapter) => chapter.id == state.requireValue.study.chapter.id,
      );
      state = const AsyncValue.loading();
      state = AsyncValue.data(
        await loadChapter(
          state.requireValue.study.id,
          chapterId:
              state.requireValue.study.chapters[currentChapterIndex + 1].id,
        ),
      );
    }
  }

  Future<StudyState> loadChapter(
    StudyId id, {
    StudyChapterId? chapterId,
  }) async {
    final (study, pgn) = await ref.withClient(
      (client) =>
          StudyRepository(client).getStudy(id: id, chapterId: chapterId),
    );

    final game = PgnGame.parsePgn(pgn);

    final pgnHeaders = IMap(game.headers);
    final rootComments = IList(game.comments.map((c) => PgnComment.fromPgn(c)));

    final options = AnalysisOptions(
      isLocalEvaluationAllowed:
          false, // TODO disable for hot reload for now. Also, get this from study data
      variant: study.chapter.setup.variant,
      orientation: study.chapter.setup.orientation,
      id: standaloneAnalysisId,
    );

    // TODO catch the case here where the position is illegal.
    _root = Root.fromPgnGame(game);

    // don't use ref.watch here: we don't want to invalidate state when the
    // analysis preferences change
    final prefs = ref.read(analysisPreferencesProvider);

    // TODO for some studies it starts with the opponent move instead of root position,
    // figure out when exactly that happens.
    const currentPath = UciPath.empty;
    Move? lastMove;

    final studyState = StudyState(
      variant: options.variant,
      study: study,
      currentPath: currentPath,
      isOnMainline: true,
      root: _root.view,
      currentNode: StudyCurrentNode.fromNode(_root),
      pgnHeaders: pgnHeaders,
      pgnRootComments: rootComments,
      lastMove: lastMove,
      pov: options.orientation,
      isLocalEvaluationAllowed: options.isLocalEvaluationAllowed,
      isLocalEvaluationEnabled: prefs.enableLocalEvaluation,
    );

    final evaluationService = ref.watch(evaluationServiceProvider);
    if (studyState.isEngineAvailable) {
      evaluationService
          .initEngine(
        _evaluationContext(studyState.variant),
        options: EvaluationOptions(
          multiPv: prefs.numEvalLines,
          cores: prefs.numEngineCores,
        ),
      )
          .then((_) {
        _startEngineEvalTimer = Timer(const Duration(milliseconds: 250), () {
          _startEngineEval();
        });
      });
    }

    return studyState;
  }

  @override
  Future<StudyState> build(StudyId id) async {
    final evaluationService = ref.watch(evaluationServiceProvider);

    ref.onDispose(() {
      _startEngineEvalTimer?.cancel();
      _engineEvalDebounce.dispose();
      evaluationService.disposeEngine();
    });

    return loadChapter(id);
  }

  EvaluationContext _evaluationContext(Variant variant) => EvaluationContext(
        variant: variant,
        initialPosition: _root.position,
      );

  void onUserMove(NormalMove move) {
    final state = this.state.valueOrNull;
    if (state == null) return;

    if (!state.position.isLegal(move)) return;

    if (isPromotionPawnMove(state.position, move)) {
      this.state = AsyncValue.data(state.copyWith(promotionMove: move));
      return;
    }

    final (newPath, isNewNode) = _root.addMoveAt(state.currentPath, move);
    if (newPath != null) {
      _setPath(
        newPath,
        shouldRecomputeRootView: isNewNode,
        shouldForceShowVariation: true,
      );
    }
  }

  void onPromotionSelection(Role? role) {
    final state = this.state.valueOrNull;
    if (state == null) return;

    if (role == null) {
      this.state = AsyncValue.data(state.copyWith(promotionMove: null));
      return;
    }
    final promotionMove = state.promotionMove;
    if (promotionMove != null) {
      final promotion = promotionMove.withPromotion(role);
      onUserMove(promotion);
    }
  }

  void userNext() {
    final state = this.state.valueOrNull;
    if (state == null || !state.currentNode.hasChild) return;
    _setPath(
      state.currentPath + _root.nodeAt(state.currentPath).children.first.id,
      replaying: true,
    );
  }

  void jumpToNthNodeOnMainline(int n) {
    UciPath path = _root.mainlinePath;
    while (!path.penultimate.isEmpty) {
      path = path.penultimate;
    }
    Node? node = _root.nodeAt(path);
    int count = 0;

    while (node != null && count < n) {
      if (node.children.isNotEmpty) {
        path = path + node.children.first.id;
        node = _root.nodeAt(path);
        count++;
      } else {
        break;
      }
    }

    if (node != null) {
      userJump(path);
    }
  }

  void toggleBoard() {
    final state = this.state.valueOrNull;
    if (state != null) {
      this.state = AsyncValue.data(state.copyWith(pov: state.pov.opposite));
    }
  }

  void userPrevious() {
    if (state.hasValue) {
      _setPath(state.requireValue.currentPath.penultimate, replaying: true);
    }
  }

  @override
  void userJump(UciPath path) {
    //print('jumping to ${path.uci} (${path.size})');
    _setPath(path);
  }

  @override
  void showAllVariations(UciPath path) {
    if (!state.hasValue) return;

    final parent = _root.parentAt(path);
    for (final node in parent.children) {
      node.isHidden = false;
    }
    state = AsyncValue.data(state.requireValue.copyWith(root: _root.view));
  }

  @override
  void hideVariation(UciPath path) {
    if (!state.hasValue) return;
    _root.hideVariationAt(path);
    state = AsyncValue.data(state.requireValue.copyWith(root: _root.view));
  }

  @override
  void promoteVariation(UciPath path, bool toMainline) {
    final state = this.state.valueOrNull;
    if (state == null) return;
    _root.promoteAt(path, toMainline: toMainline);
    this.state = AsyncValue.data(
      state.copyWith(
        isOnMainline: _root.isOnMainline(state.currentPath),
        root: _root.view,
      ),
    );
  }

  @override
  void deleteFromHere(UciPath path) {
    if (!state.hasValue) return;

    _root.deleteAt(path);
    _setPath(path.penultimate, shouldRecomputeRootView: true);
  }

  Future<void> toggleLocalEvaluation() async {
    final state = this.state.valueOrNull;
    if (state == null) return;

    ref
        .read(analysisPreferencesProvider.notifier)
        .toggleEnableLocalEvaluation();

    this.state = AsyncValue.data(
      state.copyWith(
        isLocalEvaluationEnabled: !state.isLocalEvaluationEnabled,
      ),
    );

    if (state.isEngineAvailable) {
      final prefs = ref.read(analysisPreferencesProvider);
      await ref.read(evaluationServiceProvider).initEngine(
            _evaluationContext(state.variant),
            options: EvaluationOptions(
              multiPv: prefs.numEvalLines,
              cores: prefs.numEngineCores,
            ),
          );
      _startEngineEval();
    } else {
      _stopEngineEval();
      ref.read(evaluationServiceProvider).disposeEngine();
    }
  }

  void setNumEvalLines(int numEvalLines) {
    if (!state.hasValue) return;

    ref
        .read(analysisPreferencesProvider.notifier)
        .setNumEvalLines(numEvalLines);

    ref.read(evaluationServiceProvider).setOptions(
          EvaluationOptions(
            multiPv: numEvalLines,
            cores: ref.read(analysisPreferencesProvider).numEngineCores,
          ),
        );

    _root.updateAll((node) => node.eval = null);

    state = AsyncValue.data(
      state.requireValue.copyWith(
        currentNode: StudyCurrentNode.fromNode(
          _root.nodeAt(state.requireValue.currentPath),
        ),
      ),
    );

    _startEngineEval();
  }

  void setEngineCores(int numEngineCores) {
    ref
        .read(analysisPreferencesProvider.notifier)
        .setEngineCores(numEngineCores);

    ref.read(evaluationServiceProvider).setOptions(
          EvaluationOptions(
            multiPv: ref.read(analysisPreferencesProvider).numEvalLines,
            cores: numEngineCores,
          ),
        );

    _startEngineEval();
  }

  void _setPath(
    UciPath path, {
    bool shouldForceShowVariation = false,
    bool shouldRecomputeRootView = false,
    bool replaying = false,
  }) {
    final state = this.state.valueOrNull;
    if (state == null) return;

    final pathChange = state.currentPath != path;
    final currentNode = _root.nodeAt(path);

    // always show variation if the user plays a move
    if (shouldForceShowVariation &&
        currentNode is Branch &&
        currentNode.isHidden) {
      _root.updateAt(path, (node) {
        if (node is Branch) node.isHidden = false;
      });
    }

    // root view is only used to display move list, so we need to
    // recompute the root view only when the nodelist length changes
    // or a variation is hidden/shown
    final rootView = shouldForceShowVariation || shouldRecomputeRootView
        ? _root.view
        : state.root;

    final isForward = path.size > state.currentPath.size;
    if (currentNode is Branch) {
      if (!replaying) {
        if (isForward) {
          final isCheck = currentNode.sanMove.isCheck;
          if (currentNode.sanMove.isCapture) {
            ref
                .read(moveFeedbackServiceProvider)
                .captureFeedback(check: isCheck);
          } else {
            ref.read(moveFeedbackServiceProvider).moveFeedback(check: isCheck);
          }
        }
      } else if (isForward) {
        final soundService = ref.read(soundServiceProvider);
        if (currentNode.sanMove.isCapture) {
          soundService.play(Sound.capture);
        } else {
          soundService.play(Sound.move);
        }
      }

      this.state = AsyncValue.data(
        state.copyWith(
          currentPath: path,
          isOnMainline: _root.isOnMainline(path),
          currentNode: StudyCurrentNode.fromNode(currentNode),
          lastMove: currentNode.sanMove.move,
          promotionMove: null,
          root: rootView,
        ),
      );
    } else {
      this.state = AsyncValue.data(
        state.copyWith(
          currentPath: path,
          isOnMainline: _root.isOnMainline(path),
          currentNode: StudyCurrentNode.fromNode(currentNode),
          lastMove: null,
          promotionMove: null,
          root: rootView,
        ),
      );
    }

    if (pathChange) {
      _debouncedStartEngineEval();
    }
  }

  void _startEngineEval() {
    final state = this.state.valueOrNull;
    if (state == null || !state.isEngineAvailable) return;

    ref
        .read(evaluationServiceProvider)
        .start(
          state.currentPath,
          _root.branchesOn(state.currentPath).map(Step.fromNode),
          initialPositionEval: _root.eval,
          shouldEmit: (work) => work.path == state.currentPath,
        )
        ?.forEach(
          (t) => _root.updateAt(t.$1.path, (node) => node.eval = t.$2),
        );
  }

  void _debouncedStartEngineEval() {
    _engineEvalDebounce(() {
      _startEngineEval();
    });
  }

  void _stopEngineEval() {
    ref.read(evaluationServiceProvider).stop();

    if (!state.hasValue) return;

    // update the current node with last cached eval
    state = AsyncValue.data(
      state.requireValue.copyWith(
        currentNode: StudyCurrentNode.fromNode(
          _root.nodeAt(state.requireValue.currentPath),
        ),
      ),
    );
  }
}

@freezed
class StudyState with _$StudyState {
  const StudyState._();

  const factory StudyState({
    required Study study,

    /// The variant of the current chapter
    required Variant variant,

    /// Immutable view of the whole tree
    required ViewRoot root,

    /// The current node in the study tree view.
    ///
    /// This is an immutable copy of the actual [Node] at the `currentPath`.
    /// We don't want to use [Node.view] here because it'd copy the whole tree
    /// under the current node and it's expensive.
    required StudyCurrentNode currentNode,

    /// The path to the current node in the analysis view.
    required UciPath currentPath,

    /// Whether the current path is on the mainline.
    required bool isOnMainline,

    /// The side to display the board from.
    required Side pov,

    /// Whether local evaluation is allowed for this study.
    required bool isLocalEvaluationAllowed,

    /// Whether the user has enabled local evaluation.
    required bool isLocalEvaluationEnabled,

    /// The last move played.
    Move? lastMove,

    /// Possible promotion move to be played.
    NormalMove? promotionMove,

    /// The PGN headers of the study chapter.
    required IMap<String, String> pgnHeaders,

    /// The PGN root comments of the study
    IList<PgnComment>? pgnRootComments,
  }) = _StudyState;

  IMap<Square, ISet<Square>> get validMoves =>
      makeLegalMoves(currentNode.position);

  /// Whether the engine is available for evaluation
  bool get isEngineAvailable =>
      isLocalEvaluationAllowed &&
      engineSupportedVariants.contains(variant) &&
      isLocalEvaluationEnabled;

  Position get position => currentNode.position;
  StudyChapter get currentChapter => study.chapter;
  bool get canGoNext => currentNode.hasChild;
  bool get canGoBack => currentPath.size > UciPath.empty.size;

  String get currentChapterTitle => study.chapters
      .firstWhere(
        (chapter) => chapter.id == currentChapter.id,
      )
      .name;
}

@freezed
class StudyCurrentNode with _$StudyCurrentNode {
  const StudyCurrentNode._();

  const factory StudyCurrentNode({
    required Position position,
    required bool hasChild,
    required bool isRoot,
    SanMove? sanMove,
    IList<PgnComment>? startingComments,
    IList<PgnComment>? comments,
    IList<int>? nags,
  }) = _StudyCurrentNode;

  factory StudyCurrentNode.fromNode(Node node) {
    if (node is Branch) {
      return StudyCurrentNode(
        sanMove: node.sanMove,
        position: node.position,
        isRoot: node is Root,
        hasChild: node.children.isNotEmpty,
        startingComments: IList(node.startingComments),
        comments: IList(node.comments),
        nags: IList(node.nags),
      );
    } else {
      return StudyCurrentNode(
        position: node.position,
        hasChild: node.children.isNotEmpty,
        isRoot: node is Root,
      );
    }
  }
}